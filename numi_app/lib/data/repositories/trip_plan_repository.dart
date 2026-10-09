import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../models/trip_plan.dart';
import '../local/database.dart';
import '../remote/endpoints/travel_api.dart';
import 'travel_repository.dart';

class PlanState {
  final TripPlan plan;
  final bool pending;
  final String? error;
  final TripPlan? conflict;
  PlanState(DbTripPlan? row)
      : plan = TripPlan.decode(row?.document ?? '{}'),
        pending = !(row?.synced ?? true),
        error = row?.syncError,
        conflict = row?.conflictDocument == null
            ? null
            : TripPlan.decode(row!.conflictDocument!);
}

class TripPlanRepository {
  final AppDatabase db;
  final TravelApi? api;
  final TravelRepository travel;
  Future<void>? _syncing;
  TripPlanRepository(this.db, this.api, this.travel);

  Future<DbTripPlan?> _row(int id) =>
      (db.select(db.tripPlans)..where((p) => p.tripId.equals(id)))
          .getSingleOrNull();
  Stream<PlanState> watch(int id) =>
      (db.select(db.tripPlans)..where((p) => p.tripId.equals(id)))
          .watchSingleOrNull()
          .map(PlanState.new);

  Future<void> edit(int id, void Function(TripPlan) change) async {
    await db.transaction(() async {
      final trip = await db.tripDao.getById(id);
      if (trip == null || trip.deleted) {
        throw StateError('Trip no longer exists');
      }
      final row = await _row(id);
      final plan = TripPlan.decode(row?.document ?? '{}');
      change(plan);
      final document = plan.encode();
      if (plan.places.length > 1000 ||
          plan.entries.length > 1000 ||
          plan.checks.length > 1000 ||
          plan.dayNotes.length > 1000 ||
          utf8.encode(document).length > 1900000) {
        throw StateError(
            'This plan is too large. Remove unused items or split it into separate trips.');
      }
      await db.into(db.tripPlans).insertOnConflictUpdate(
          TripPlansCompanion.insert(
              tripId: Value(id),
              document: Value(document),
              version: Value(row?.version ?? 0),
              synced: const Value(false),
              changeId: Value(newTravelId()),
              conflictDocument: Value(row?.conflictDocument),
              conflictVersion: Value(row?.conflictVersion),
              syncError: const Value(null)));
    });
    unawaited(sync());
  }

  Future<void> resolve(int id, {required bool keepMine}) async {
    await db.transaction(() async {
      final row = await _row(id);
      if (row?.conflictDocument == null) return;
      await (db.update(db.tripPlans)..where((p) => p.tripId.equals(id)))
          .write(TripPlansCompanion(
        document: Value(keepMine ? row!.document : row!.conflictDocument!),
        version: Value(row.conflictVersion!),
        synced: Value(!keepMine),
        changeId: Value(newTravelId()),
        conflictDocument: const Value(null),
        conflictVersion: const Value(null),
        syncError: const Value(null),
      ));
    });
    unawaited(sync());
  }

  Future<void> sync() {
    if (api == null) return Future.value();
    return _syncing ??= _sync().whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    await travel.syncPending();
    final trips = await (db.select(db.trips)
          ..where((t) => t.deleted.equals(false)))
        .get();
    for (final trip in trips) {
      if (trip.remoteId == null) continue;
      try {
        // New edits while a request is in flight get a fresh revision next pass.
        while (true) {
          final row = await _row(trip.id);
          if (row?.conflictDocument != null) break;
          if (row != null && !row.synced) {
            try {
              final response = await api!.putPlan(trip.remoteId!, {
                'document': jsonDecode(row.document),
                'version': row.version,
                '_mutation_id': row.changeId
              });
              await db.transaction(() async {
                final current = await _row(trip.id);
                if (current == null) return;
                await (db.update(db.tripPlans)
                      ..where((p) => p.tripId.equals(trip.id)))
                    .write(TripPlansCompanion(
                        version: Value(response['version'] as int),
                        synced: Value(current.changeId == row.changeId),
                        syncError: const Value(null)));
              });
            } on DioException catch (e) {
              if (e.response?.statusCode == 409 &&
                  e.response?.data is Map &&
                  e.response!.data['document'] is Map) {
                final server = e.response!.data as Map;
                await (db.update(db.tripPlans)
                      ..where((p) => p.tripId.equals(trip.id)))
                    .write(TripPlansCompanion(
                        conflictDocument: Value(jsonEncode(server['document'])),
                        conflictVersion: Value(server['version'] as int),
                        syncError: const Value(
                            'This plan changed on another device.')));
                break;
              }
              rethrow;
            }
          } else {
            final response = await api!.getPlan(trip.remoteId!);
            await db.transaction(() async {
              final currentTrip = await db.tripDao.getById(trip.id);
              if (currentTrip == null || currentTrip.deleted) return;
              final current = await _row(trip.id);
              if (current != null && !current.synced) return;
              await db.into(db.tripPlans).insertOnConflictUpdate(
                  TripPlansCompanion.insert(
                      tripId: Value(trip.id),
                      document: Value(jsonEncode(response['document'])),
                      version: Value(response['version'] as int),
                      synced: const Value(true),
                      syncError: const Value(null)));
            });
            // An edit during GET must still be flushed, not stranded until restart.
            final latest = await _row(trip.id);
            if (latest != null && !latest.synced) continue;
            break;
          }
        }
      } catch (e) {
        final message = e is DioException && e.response != null
            ? 'Could not sync plan (${e.response!.statusCode}). Your changes are saved on this device.'
            : 'Offline — your changes are saved on this device.';
        await (db.update(db.tripPlans)..where((p) => p.tripId.equals(trip.id)))
            .write(TripPlansCompanion(syncError: Value(message)));
      }
    }
  }
}
