import 'dart:convert';
import 'dart:async';
import 'package:drift/drift.dart';
import '../../utils/app_logger.dart';
import '../../models/travel_expense.dart' as model;
import '../../models/trip.dart' as model;
import '../../models/trip_plan.dart';
import '../../utils/currency_utils.dart';
import '../local/database.dart';
import '../remote/endpoints/travel_api.dart';
import 'rate_repository.dart';

class TravelRepository {
  final AppDatabase _db;
  final TravelApi? _api;
  final RateRepository _rateRepo;
  Future<void>? _syncing;
  TravelRepository(this._db, this._api, this._rateRepo);

  Future<void> _enqueue(String entity, String operation, int localId,
          Map<String, dynamic> payload) =>
      _db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        entityType: entity,
        operation: operation,
        localId: localId,
        payload: jsonEncode({...payload, '_mutation_id': newTravelId()}),
        createdAt: Value(DateTime.now()),
      ));

  Stream<List<model.Trip>> watchAllTrips() => _db
      .customSelect(
        'SELECT t.id FROM trips t LEFT JOIN travel_expenses e ON e.trip_id = t.id',
        readsFrom: {_db.trips, _db.travelExpenses},
      )
      .watch()
      .asyncMap((_) async {
        final rows = await (_db.select(_db.trips)
              ..where((t) => t.deleted.equals(false))
              ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
            .get();
        return Future.wait(rows.map((t) async =>
            _tripToModel(t, await _db.tripDao.getExpensesForTrip(t.id))));
      });

  Future<model.Trip?> getTripWithExpenses(int id) async {
    final row = await _db.tripDao.getById(id);
    if (row == null || row.deleted) return null;
    return _tripToModel(row, await _db.tripDao.getExpensesForTrip(id));
  }

  Stream<model.Trip?> watchTripWithExpenses(int id) => _db
      .customSelect(
        'SELECT t.id FROM trips t LEFT JOIN travel_expenses e ON e.trip_id = t.id WHERE t.id = ?',
        variables: [Variable.withInt(id)],
        readsFrom: {_db.trips, _db.travelExpenses},
      )
      .watch()
      .asyncMap((_) => getTripWithExpenses(id));

  Future<void> addTrip(
      {required String destination,
      required DateTime startDate,
      required DateTime endDate,
      String notes = ''}) async {
    await _db.transaction(() async {
      final id = await _db.tripDao.insertTrip(TripsCompanion.insert(
          destination: destination,
          startDate: startDate,
          endDate: endDate,
          notes: Value(notes),
          createdAt: Value(DateTime.now())));
      await _enqueue('trip', 'create', id, {
        'destination': destination,
        'start_date': planDate(startDate),
        'end_date': planDate(endDate),
        'notes': notes
      });
    });
    unawaited(syncPending());
  }

  Future<void> deleteTrip(int id) async {
    await _db.transaction(() async {
      final row = await _db.tripDao.getById(id);
      if (row == null || row.deleted) return;
      await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
          const TripsCompanion(deleted: Value(true), synced: Value(false)));
      await _enqueue('trip', 'delete', id, {'remote_id': row.remoteId});
    });
    unawaited(syncPending());
  }

  Future<void> addTravelExpense(
      {required int tripId,
      required double amount,
      required String currency,
      required DateTime date,
      required String category,
      required String name,
      String notes = '',
      String plannerEntryId = ''}) async {
    final computed = CurrencyUtils.computeAmounts(
        amount, currency, await _rateRepo.getCachedRates());
    await _db.transaction(() async {
      final trip = await _db.tripDao.getById(tripId);
      if (trip == null || trip.deleted) {
        throw StateError('Trip no longer exists');
      }
      final id =
          await _db.tripDao.insertTravelExpense(TravelExpensesCompanion.insert(
        tripId: tripId,
        tripRemoteId: Value(trip.remoteId),
        amount: amount,
        currency: currency,
        date: date,
        category: category,
        name: name,
        notes: Value(notes),
        plannerEntryId: Value(plannerEntryId),
        amountUsd: Value(computed['amount_usd']!),
        amountCny: Value(computed['amount_cny']!),
        amountHkd: Value(computed['amount_hkd']!),
        amountSgd: Value(computed['amount_sgd']!),
        createdAt: Value(DateTime.now()),
      ));
      await _enqueue('travel_expense', 'create', id, {
        'trip_id': tripId,
        'amount': amount,
        'currency': currency,
        'date': planDate(date),
        'category': category,
        'name': name,
        'notes': notes,
        'planner_entry_id': plannerEntryId
      });
    });
    unawaited(syncPending());
  }

  Future<void> updateTravelExpense(int id,
      {required double amount,
      required String currency,
      required DateTime date,
      required String category,
      required String name,
      String notes = '',
      String? plannerEntryId}) async {
    final computed = CurrencyUtils.computeAmounts(
        amount, currency, await _rateRepo.getCachedRates());
    await _db.transaction(() async {
      final row = await (_db.select(_db.travelExpenses)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (row == null || row.deleted) {
        throw StateError('Expense no longer exists');
      }
      final link = plannerEntryId ?? row.plannerEntryId;
      await _db.tripDao.updateTravelExpenseRow(
          id,
          TravelExpensesCompanion(
              amount: Value(amount),
              currency: Value(currency),
              date: Value(date),
              category: Value(category),
              name: Value(name),
              notes: Value(notes),
              plannerEntryId: Value(link),
              amountUsd: Value(computed['amount_usd']!),
              amountCny: Value(computed['amount_cny']!),
              amountHkd: Value(computed['amount_hkd']!),
              amountSgd: Value(computed['amount_sgd']!),
              synced: const Value(false)));
      await _enqueue('travel_expense', 'update', id, {
        'trip_id': row.tripId,
        'amount': amount,
        'currency': currency,
        'date': planDate(date),
        'category': category,
        'name': name,
        'notes': notes,
        'planner_entry_id': link
      });
    });
    unawaited(syncPending());
  }

  Future<void> deleteTravelExpense(int id, int tripId) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.travelExpenses)
            ..where((e) => e.id.equals(id)))
          .getSingleOrNull();
      if (row == null || row.deleted) return;
      await _db.tripDao.updateTravelExpenseRow(
          id,
          const TravelExpensesCompanion(
              deleted: Value(true), synced: Value(false)));
      await _enqueue('travel_expense', 'delete', id, {
        'trip_id': tripId,
        'remote_id': row.remoteId,
        'trip_remote_id': row.tripRemoteId
      });
    });
    unawaited(syncPending());
  }

  Future<void> _removeTrip(int id) async {
    final expenses = await (_db.select(_db.travelExpenses)
          ..where((e) => e.tripId.equals(id)))
        .get();
    for (final e in expenses) {
      await (_db.delete(_db.syncQueue)
            ..where((q) =>
                q.entityType.equals('travel_expense') & q.localId.equals(e.id)))
          .go();
    }
    await (_db.delete(_db.travelExpenses)..where((e) => e.tripId.equals(id)))
        .go();
    await (_db.delete(_db.tripPlans)..where((p) => p.tripId.equals(id))).go();
    await _db.tripDao.removeTripById(id);
  }

  /// A single writer drains immutable operations in order; failures stay visible
  /// in the existing pending badge and are retried on the next sync.
  Future<void> syncPending() {
    if (_api == null) return Future.value();
    return _syncing ??= _flush().whenComplete(() => _syncing = null);
  }

  Future<void> _repairLegacyQueue() async {
    await _db.transaction(() async {
      final pending = await _db.syncQueueDao.getPending();
      final keys = pending.map((q) => '${q.entityType}:${q.localId}').toSet();
      final trips = await (_db.select(_db.trips)
            ..where((t) => t.synced.equals(false) & t.deleted.equals(false)))
          .get();
      for (final t in trips) {
        if (t.remoteId == null && !keys.contains('trip:${t.id}')) {
          await _enqueue('trip', 'create', t.id, {
            'destination': t.destination,
            'start_date': planDate(t.startDate),
            'end_date': planDate(t.endDate),
            'notes': t.notes
          });
        }
      }
      final expenses = await (_db.select(_db.travelExpenses)
            ..where((e) => e.synced.equals(false) & e.deleted.equals(false)))
          .get();
      for (final e in expenses) {
        if (!keys.contains('travel_expense:${e.id}')) {
          await _enqueue('travel_expense',
              e.remoteId == null ? 'create' : 'update', e.id, {
            'trip_id': e.tripId,
            'amount': e.amount,
            'currency': e.currency,
            'date': planDate(e.date),
            'category': e.category,
            'name': e.name,
            'notes': e.notes,
            'planner_entry_id': e.plannerEntryId
          });
        }
      }
    });
  }

  Future<void> _flush() async {
    try {
      await _repairLegacyQueue();
      while (true) {
        final operations = (await _db.syncQueueDao.getPending())
            .where((q) =>
                q.entityType == 'trip' || q.entityType == 'travel_expense')
            .toList();
        if (operations.isEmpty) return;
        final op = operations.first;
        final payload = Map<String, dynamic>.from(jsonDecode(op.payload));
        // Released clients sometimes left an already-synced create in their
        // queue. Drop only these legacy operations, never new ordered updates.
        if (!payload.containsKey('_mutation_id') && op.operation != 'delete') {
          final legacySynced = op.entityType == 'trip'
              ? await (_db.select(_db.trips)
                        ..where((t) =>
                            t.id.equals(op.localId) &
                            t.synced.equals(true) &
                            t.remoteId.isNotNull()))
                      .getSingleOrNull() !=
                  null
              : await (_db.select(_db.travelExpenses)
                        ..where((e) =>
                            e.id.equals(op.localId) &
                            e.synced.equals(true) &
                            e.remoteId.isNotNull()))
                      .getSingleOrNull() !=
                  null;
          if (legacySynced) {
            await _db.syncQueueDao.removeById(op.id);
            continue;
          }
        }
        // Upgrade old queued writes once, before their first attempt.
        if (!payload.containsKey('_mutation_id')) {
          payload['_mutation_id'] = newTravelId();
          await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
              .write(SyncQueueCompanion(payload: Value(jsonEncode(payload))));
        }
        if (payload['date'] is String) {
          payload['date'] = (payload['date'] as String).split('T').first;
        }
        for (final key in ['start_date', 'end_date']) {
          if (payload[key] is String) {
            payload[key] = (payload[key] as String).split('T').first;
          }
        }
        try {
          if (op.entityType == 'trip') {
            final row = await _db.tripDao.getById(op.localId);
            if (op.operation == 'create' && row != null) {
              final response = await _api!.addTrip(payload);
              final remoteId = response['id'] as int;
              await _db.transaction(() async {
                await (_db.update(_db.trips)
                      ..where((t) => t.id.equals(op.localId)))
                    .write(TripsCompanion(remoteId: Value(remoteId)));
                await (_db.update(_db.travelExpenses)
                      ..where((e) => e.tripId.equals(op.localId)))
                    .write(
                        TravelExpensesCompanion(tripRemoteId: Value(remoteId)));
              });
            } else if (op.operation == 'delete') {
              final remoteId = row?.remoteId ?? payload['remote_id'] as int?;
              if (remoteId != null) {
                await _api!.deleteTrip(remoteId, payload: payload);
              }
              await _db.transaction(() => _removeTrip(op.localId));
            }
          } else {
            final row = await (_db.select(_db.travelExpenses)
                  ..where((e) => e.id.equals(op.localId)))
                .getSingleOrNull();
            final trip =
                row == null ? null : await _db.tripDao.getById(row.tripId);
            final tripRemoteId =
                trip?.remoteId ?? payload['trip_remote_id'] as int?;
            if (op.operation == 'delete') {
              final remoteId = row?.remoteId ?? payload['remote_id'] as int?;
              if (remoteId != null && tripRemoteId != null) {
                await _api!.deleteTripExpense(tripRemoteId, remoteId,
                    payload: payload);
              }
              await _db.tripDao.removeTravelExpenseById(op.localId);
            } else if (row != null) {
              if (tripRemoteId == null) {
                throw StateError('Waiting for trip to sync');
              }
              if (op.operation == 'create') {
                final response =
                    await _api!.addTripExpense(tripRemoteId, payload);
                await _db.tripDao.updateTravelExpenseRow(
                    row.id,
                    TravelExpensesCompanion(
                        remoteId: Value(response['id'] as int),
                        tripRemoteId: Value(tripRemoteId)));
              } else {
                if (row.remoteId == null) {
                  throw StateError('Waiting for expense to sync');
                }
                await _api!
                    .updateTripExpense(tripRemoteId, row.remoteId!, payload);
              }
            }
          }
          await _db.transaction(() async {
            await _db.syncQueueDao.removeById(op.id);
            final more = await (_db.select(_db.syncQueue)
                  ..where((q) =>
                      q.entityType.equals(op.entityType) &
                      q.localId.equals(op.localId)))
                .get();
            if (more.isEmpty) {
              if (op.entityType == 'trip') {
                await (_db.update(_db.trips)
                      ..where((t) => t.id.equals(op.localId)))
                    .write(const TripsCompanion(synced: Value(true)));
              } else {
                await _db.tripDao.updateTravelExpenseRow(op.localId,
                    const TravelExpensesCompanion(synced: Value(true)));
              }
            }
          });
        } catch (e, st) {
          await _db.syncQueueDao.incrementRetry(op.id);
          AppLogger.instance.log('Travel sync pending: $e',
              name: 'TravelRepo', error: e, stackTrace: st);
          return;
        }
      }
    } catch (e, st) {
      AppLogger.instance.log('Travel sync failed: $e',
          name: 'TravelRepo', error: e, stackTrace: st);
    }
  }

  Future<void> syncFromServer(String currency) async {
    if (_api == null) return;
    await syncPending();
    if (_syncing != null) await _syncing;
    _syncing = _pull(currency)
        .then((_) => _flush())
        .whenComplete(() => _syncing = null);
    await _syncing;
  }

  Future<void> _pull(String currency) async {
    final api = _api!;
    // Resolve a possibly accepted create before importing remote rows.
    if ((await _db.syncQueueDao.getPending()).any(
        (q) => q.entityType == 'trip' || q.entityType == 'travel_expense')) {
      return;
    }
    try {
      final trips = await api.getTrips(currency: currency);
      for (final t in trips) {
        final remoteId = t['id'] as int;
        var local = await (_db.select(_db.trips)
              ..where((row) => row.remoteId.equals(remoteId)))
            .getSingleOrNull();
        if (local != null && (!local.synced || local.deleted)) continue;
        await _db.tripDao.upsertTripByRemoteId(TripsCompanion(
            remoteId: Value(remoteId),
            destination: Value(t['destination'] as String),
            startDate: Value(DateTime.parse(t['start_date'] as String)),
            endDate: Value(DateTime.parse(t['end_date'] as String)),
            notes: Value(t['notes'] as String? ?? ''),
            synced: const Value(true)));
        local = await (_db.select(_db.trips)
              ..where((row) => row.remoteId.equals(remoteId)))
            .getSingle();
        final expenses =
            await api.getTripExpenses(remoteId, currency: currency);
        await _db.transaction(() async {
          for (final e in expenses) {
            final existing = await (_db.select(_db.travelExpenses)
                  ..where((row) => row.remoteId.equals(e['id'] as int)))
                .getSingleOrNull();
            if (existing != null && (!existing.synced || existing.deleted)) {
              continue;
            }
            await _db.tripDao.upsertTravelExpenseByRemoteId(
                TravelExpensesCompanion(
                    remoteId: Value(e['id'] as int),
                    tripId: Value(local!.id),
                    tripRemoteId: Value(remoteId),
                    amount: Value((e['amount'] as num).toDouble()),
                    currency: Value(e['currency'] as String),
                    date: Value(DateTime.parse(e['date'] as String)),
                    category: Value(e['category'] as String),
                    name: Value(e['name'] as String),
                    notes: Value(e['notes'] as String? ?? ''),
                    plannerEntryId:
                        Value(e['planner_entry_id'] as String? ?? ''),
                    amountUsd:
                        Value((e['amount_usd'] as num?)?.toDouble() ?? 0),
                    amountCny:
                        Value((e['amount_cny'] as num?)?.toDouble() ?? 0),
                    amountHkd:
                        Value((e['amount_hkd'] as num?)?.toDouble() ?? 0),
                    amountSgd:
                        Value((e['amount_sgd'] as num?)?.toDouble() ?? 0),
                    synced: const Value(true)));
          }
          final ids = expenses.map((e) => e['id'] as int).toSet();
          await (_db.delete(_db.travelExpenses)
                ..where((e) =>
                    e.tripId.equals(local!.id) &
                    e.synced.equals(true) &
                    e.remoteId.isNotNull() &
                    e.remoteId.isNotIn(ids)))
              .go();
        });
      }
      final remoteIds = trips.map((t) => t['id'] as int).toSet();
      await _db.transaction(() async {
        final gone = await (_db.select(_db.trips)
              ..where((t) =>
                  t.synced.equals(true) &
                  t.remoteId.isNotNull() &
                  t.remoteId.isNotIn(remoteIds)))
            .get();
        for (final row in gone) {
          // Preserve locally edited plans when a trip was deleted elsewhere.
          final plan = await (_db.select(_db.tripPlans)
                ..where((p) => p.tripId.equals(row.id)))
              .getSingleOrNull();
          final pendingExpenses = await (_db.select(_db.travelExpenses)
                ..where(
                    (e) => e.tripId.equals(row.id) & e.synced.equals(false)))
              .get();
          if ((plan == null || plan.synced) && pendingExpenses.isEmpty) {
            await _removeTrip(row.id);
          }
        }
      });
    } catch (e, st) {
      AppLogger.instance.log('syncFromServer failed: $e',
          name: 'TravelRepo', error: e, stackTrace: st);
    }
  }

  model.Trip _tripToModel(DbTrip row, List<DbTravelExpense> expenseRows) =>
      model.Trip(
        id: row.id,
        remoteId: row.remoteId,
        destination: row.destination,
        startDate: row.startDate,
        endDate: row.endDate,
        notes: row.notes,
        createdAt: row.createdAt,
        synced: row.synced,
        expenses: expenseRows.map(_expenseToModel).toList(),
      );

  model.TravelExpense _expenseToModel(DbTravelExpense row) =>
      model.TravelExpense(
        id: row.id,
        remoteId: row.remoteId,
        tripId: row.tripId,
        tripRemoteId: row.tripRemoteId,
        plannerEntryId: row.plannerEntryId,
        amount: row.amount,
        currency: row.currency,
        date: row.date,
        category: row.category,
        name: row.name,
        notes: row.notes,
        amountUsd: row.amountUsd,
        amountCny: row.amountCny,
        amountHkd: row.amountHkd,
        amountSgd: row.amountSgd,
        createdAt: row.createdAt,
        synced: row.synced,
      );
}
