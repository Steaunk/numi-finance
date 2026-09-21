import 'dart:convert';
import 'dart:async';
import 'booking_payment_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../models/trip_plan.dart';
import '../local/database.dart';
import '../remote/endpoints/travel_api.dart';

class TripPlanRepository {
  final AppDatabase db;
  final TravelApi? api;
  final Map<int, Future<void>> _running = {};
  final Set<int> _needsSync = {};
  final Future<void> Function()? prepareTrip;
  TripPlanRepository(this.db, this.api, {this.prepareTrip});

  Future<DbTripPlan?> _row(int tripId) =>
      (db.select(db.tripPlans)..where((p) => p.tripId.equals(tripId)))
          .getSingleOrNull();

  Stream<TripPlan> watch(int tripId) => (db.select(db.tripPlans)
        ..where((p) => p.tripId.equals(tripId)))
      .watchSingleOrNull()
      .map((r) => r == null
          ? TripPlan()
          : TripPlan.decode(r.content, pending: r.dirty, error: r.syncError));

  Future<void> _edit(
      int tripId, List<PlanItem> Function(List<PlanItem>) change) async {
    await db.transaction(() async {
      if (await db.tripDao.getById(tripId) == null) {
        throw StateError('Trip no longer exists');
      }
      final row = await _row(tripId);
      final items = row == null
          ? <PlanItem>[]
          : TripPlan.decode(row.content).items.toList();
      final updated = change(items);
      await reconcileBookingPayments(db, tripId, updated);
      final content = TripPlan(items: updated).encode();
      await db.into(db.tripPlans).insertOnConflictUpdate(TripPlansCompanion(
            tripId: Value(tripId),
            content: Value(content),
            dirty: const Value(true),
            mutationId: Value(newPlanId()),
            serverRevision: Value(row?.serverRevision ?? 0),
            syncError: Value(row?.syncError == 'conflict' ? 'conflict' : ''),
          ));
    });
    _needsSync.add(tripId);
    unawaited(sync(tripId));
  }

  Future<void> save(int tripId, PlanItem item) => _edit(tripId, (items) {
        if (item.kind == 'destination' &&
            (item['date'].isEmpty ||
                item['endDate'].isEmpty ||
                item['endDate'].compareTo(item['date']) < 0)) {
          throw StateError('Choose arrival and departure dates in order.');
        }
        for (final key in ['destinationId', 'endDestinationId']) {
          if (item[key].isNotEmpty &&
              !items.any((i) => i.kind == 'destination' && i.id == item[key])) {
            throw StateError(
                'The linked destination was removed. Choose another destination.');
          }
        }
        if (item['placeId'].isNotEmpty &&
            !items.any((i) => i.kind == 'place' && i.id == item['placeId'])) {
          throw StateError(
              'The linked place was removed. Choose another place.');
        }
        if ((item.kind == 'booking' || item.kind == 'activity') &&
            item['paymentStatus'] == 'paid') {
          item = item.copy({
            'expenseClientId': item['expenseClientId'].isEmpty
                ? newPlanId()
                : item['expenseClientId'],
            'expenseCategory': item['expenseCategory'].isEmpty
                ? planExpenseCategory(items
                        .where((p) => p.id == item['placeId'])
                        .firstOrNull?['category'] ??
                    item['category'])
                : item['expenseCategory'],
          });
        }
        final index = items.indexWhere((i) => i.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        return items;
      });

  Future<PlanItem> itemFromExpense(int tripId, int expenseId,
      {String kind = 'booking'}) async {
    return db.transaction(() async {
      final expense = await (db.select(db.travelExpenses)
            ..where((e) => e.id.equals(expenseId) & e.tripId.equals(tripId)))
          .getSingle();
      final trip = (await db.tripDao.getById(tripId))!;
      final planRow = await _row(tripId);
      final plan =
          planRow == null ? TripPlan() : TripPlan.decode(planRow.content);
      if (expense.planItemId != null) {
        final booking = plan.find(expense.planItemId!);
        if (booking == null) {
          throw StateError('Sync this trip to load its itinerary item.');
        }
        return booking;
      }
      final clientId = expense.clientId ??
          (expense.remoteId == null
              ? newPlanId()
              : 'remote-${expense.remoteId}');
      await db.tripDao.updateTravelExpenseRow(
          expense.id, TravelExpensesCompanion(clientId: Value(clientId)));
      return PlanItem.create(kind).copy({
        'title': expense.name,
        'notes': expense.notes,
        'category': kind == 'activity'
            ? 'Activity'
            : expense.category == 'Accommodation'
                ? 'Accommodation'
                : 'Reservation',
        'date': planDate(trip.startDate),
        if (kind == 'booking' && expense.category == 'Accommodation')
          'endDate': planDate(trip.endDate.isAfter(trip.startDate)
              ? trip.endDate
              : trip.startDate.add(const Duration(days: 1))),
        'status': 'confirmed',
        'amount': expense.amount.toString(),
        'currency': expense.currency,
        'paymentStatus': 'paid',
        'paidDate': planDate(expense.date),
        'expenseClientId': clientId,
        'expenseCategory': expense.category,
      });
    });
  }

  Future<void> removePayment(int tripId, String planItemId) async {
    final plan = await watch(tripId).first;
    final booking = plan.find(planItemId);
    if (booking == null) {
      throw StateError('Load the linked itinerary item first.');
    }
    await save(tripId, booking.copy({'paymentStatus': 'unpaid'}));
  }

  Future<void> remove(int tripId, String id) => _edit(
      tripId,
      (items) => items
          .where((i) => i.id != id)
          .map((i) => i.copy({
                if (i['destinationId'] == id) 'destinationId': '',
                if (i['endDestinationId'] == id) 'endDestinationId': '',
                if (i['placeId'] == id) ...{
                  'placeId': '',
                  'destinationId':
                      items.firstWhere((p) => p.id == id)['destinationId'],
                  'title': i.title.isEmpty
                      ? items.firstWhere((p) => p.id == id).title
                      : i.title
                }
              }))
          .toList());

  Future<void> reorder(int tripId, List<String> orderedIds) =>
      _edit(tripId, (items) {
        final selected = {
          for (final i in items)
            if (orderedIds.contains(i.id)) i.id: i
        };
        if (selected.length != orderedIds.length ||
            orderedIds.toSet().length != orderedIds.length) {
          throw StateError('The itinerary changed; refresh and try again.');
        }
        var next = 0;
        return items
            .map((i) =>
                selected.containsKey(i.id) ? selected[orderedIds[next++]]! : i)
            .toList();
      });

  Future<void> syncAll() async {
    for (final trip in await db.tripDao.getAllTrips()) {
      await sync(trip.id);
    }
  }

  Future<void> sync(int tripId) {
    final running = _running[tripId];
    if (running != null) return running;
    final future = _drain(tripId).whenComplete(() {
      _running.remove(tripId);
    });
    _running[tripId] = future;
    return future;
  }

  Future<void> _drain(int tripId) async {
    do {
      _needsSync.remove(tripId);
      await _sync(tripId);
    } while (_needsSync.contains(tripId));
  }

  Future<void> _sync(int tripId) async {
    final remote = api;
    if (remote == null) return;
    try {
      await prepareTrip?.call();
      final trip = await db.transaction(() async {
        final parent = await db.tripDao.getById(tripId);
        if (parent == null) return null;
        await db.into(db.tripPlans).insert(
            TripPlansCompanion(tripId: Value(tripId)),
            mode: InsertMode.insertOrIgnore);
        return parent;
      });
      if (trip == null) return;
      if (trip.remoteId == null) return;
      var row = await _row(tripId);
      if (row?.syncError == 'conflict') return;
      while (row != null && row.dirty) {
        final result = await remote.putPlan(trip.remoteId!, {
          'content': jsonDecode(row.content),
          'revision': row.serverRevision,
          'mutation_id': row.mutationId,
        });
        await db.transaction(() async {
          final current = await _row(tripId);
          if (current == null) return;
          final ids = result['payment_ids'] as Map?;
          if (ids != null) {
            for (final entry in ids.entries) {
              await (db.update(db.travelExpenses)
                    ..where((e) =>
                        e.tripId.equals(tripId) &
                        e.clientId.equals(entry.key as String)))
                  .write(TravelExpensesCompanion(
                      remoteId: Value(entry.value as int),
                      tripRemoteId: Value(trip.remoteId)));
            }
          }
          await (db.update(db.tripPlans)..where((p) => p.tripId.equals(tripId)))
              .write(TripPlansCompanion(
                  serverRevision: Value(result['revision'] as int),
                  dirty: Value(current.mutationId != row!.mutationId),
                  syncError: const Value('')));
        });
        row = await _row(tripId);
      }
      final result = await remote.getPlan(trip.remoteId!);
      await db.transaction(() async {
        if (await db.tripDao.getById(tripId) == null) return;
        final current = await _row(tripId);
        if (current?.dirty == true) return;
        await reconcileBookingPayments(
            db, tripId, TripPlan.decode(jsonEncode(result['content'])).items,
            serverIds:
                (result['payment_ids'] as Map?)?.cast<String, dynamic>());
        await db.into(db.tripPlans).insertOnConflictUpdate(TripPlansCompanion(
              tripId: Value(tripId),
              content: Value(jsonEncode(result['content'])),
              serverRevision: Value(result['revision'] as int),
              dirty: const Value(false),
              syncError: const Value(''),
            ));
      });
    } catch (error) {
      final message = error is DioException && error.response?.statusCode == 409
          ? 'conflict'
          : 'Could not sync. Your plan is saved on this device. Try again when connected.';
      await (db.update(db.tripPlans)..where((p) => p.tripId.equals(tripId)))
          .write(TripPlansCompanion(syncError: Value(message)));
    }
  }

  /// Explicit user decision; never overwrite an unseen remote edit automatically.
  Future<void> resolve(int tripId, {required bool keepLocal}) async {
    final trip = await db.tripDao.getById(tripId);
    if (api == null || trip?.remoteId == null) {
      throw StateError('Connect to the server first');
    }
    final running = _running[tripId];
    if (running != null) await running;
    final before = await _row(tripId);
    final result = await api!.getPlan(trip!.remoteId!);
    await db.transaction(() async {
      final latest = await _row(tripId);
      if (latest == null || latest.mutationId != before?.mutationId) {
        throw StateError(
            'Plan changed while resolving. Review it and try again.');
      }
      if (!keepLocal) {
        await reconcileBookingPayments(
            db, tripId, TripPlan.decode(jsonEncode(result['content'])).items,
            serverIds:
                (result['payment_ids'] as Map?)?.cast<String, dynamic>() ?? {});
      }
      await (db.update(db.tripPlans)..where((p) => p.tripId.equals(tripId)))
          .write(TripPlansCompanion(
              serverRevision: Value(result['revision'] as int),
              content: keepLocal
                  ? const Value.absent()
                  : Value(jsonEncode(result['content'])),
              dirty: Value(keepLocal),
              mutationId: Value(newPlanId()),
              syncError: const Value('')));
    });
    await sync(tripId);
  }
}
