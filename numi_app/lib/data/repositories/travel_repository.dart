import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import '../../models/trip_plan.dart';
import '../../utils/app_logger.dart';
import 'package:drift/drift.dart';
import '../../models/travel_expense.dart' as model;
import '../../models/trip.dart' as model;
import '../../utils/currency_utils.dart';
import '../../utils/date_utils.dart';
import '../local/database.dart';
import '../remote/endpoints/travel_api.dart';
import 'rate_repository.dart';

class TravelRepository {
  final AppDatabase _db;
  final TravelApi? _api;
  final RateRepository _rateRepo;

  final Future<void> Function(int)? preparePlan;
  TravelRepository(this._db, this._api, this._rateRepo, {this.preparePlan});

  Future<void> _tripWork = Future.value();
  Future<T> _serializeTrips<T>(Future<T> Function() action) {
    final result = _tripWork.then((_) => action());
    _tripWork =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> flushTrips() => _serializeTrips(_flushTrips);

  Future<void> _flushTrips() async {
    final api = _api;
    if (api == null) return;
    // Recover local-only trips created by older app versions before a server was set.
    final queued = (await _db.syncQueueDao.getPending())
        .where((q) => q.entityType == 'trip')
        .map((q) => q.localId)
        .toSet();
    for (final row in await _db.tripDao.getAllTrips()) {
      if (row.remoteId == null && !queued.contains(row.id)) {
        await _enqueue('trip', 'create', row.id, {
          'destination': row.destination,
          'start_date': AppDateUtils.formatDate(row.startDate),
          'end_date': AppDateUtils.formatDate(row.endDate),
          'notes': row.notes,
          'client_id': newPlanId(),
        });
      }
    }
    for (final op in await _db.syncQueueDao.getPending()) {
      if (op.entityType != 'trip') continue;
      try {
        final payload =
            Map<String, dynamic>.from(jsonDecode(op.payload) as Map);
        if (op.operation == 'create') {
          final row = await _db.tripDao.getById(op.localId);
          if (row == null || row.remoteId != null) {
            await _db.syncQueueDao.removeById(op.id);
            continue;
          }
          // Stable key makes a timeout after server commit safe to retry.
          if (payload['client_id'] == null) {
            payload['client_id'] = newPlanId();
            await (_db.update(_db.syncQueue)..where((q) => q.id.equals(op.id)))
                .write(SyncQueueCompanion(payload: Value(jsonEncode(payload))));
          }
          for (final key in ['start_date', 'end_date']) {
            payload[key] = (payload[key] as String).split('T').first;
          }
          final remote = await api.addTrip(payload);
          await (_db.update(_db.trips)..where((t) => t.id.equals(op.localId)))
              .write(TripsCompanion(
                  remoteId: Value(remote['id'] as int),
                  synced: const Value(true)));
        } else if (op.operation == 'delete' && payload['remote_id'] != null) {
          try {
            await api.deleteTrip(payload['remote_id'] as int);
          } on DioException catch (e) {
            if (e.response?.statusCode != 404) rethrow;
          }
        }
        if (op.operation == 'delete' &&
            payload['remote_id'] == null &&
            payload['client_id'] != null) {
          await api.deleteTripByClient(payload['client_id'] as String);
        }
        await _db.syncQueueDao.removeById(op.id);
      } catch (e, st) {
        AppLogger.instance.log('Trip sync remains pending: $e',
            name: 'TravelRepo', error: e, stackTrace: st);
        // Keep recoverable operations, including deletes, without a retry cap.
      }
    }
  }

  Future<void> _removeTripData(int localId) async {
    final expenseIds = (await _db.tripDao.getExpensesForTrip(localId))
        .map((e) => e.id)
        .toList();
    await (_db.delete(_db.syncQueue)
          ..where((q) =>
              (q.entityType.equals('trip') & q.localId.equals(localId)) |
              (q.entityType.equals('travel_expense') &
                  q.localId.isIn(expenseIds))))
        .go();
    await (_db.delete(_db.travelExpenses)
          ..where((e) => e.tripId.equals(localId)))
        .go();
    await (_db.delete(_db.tripPlans)..where((p) => p.tripId.equals(localId)))
        .go();
    await _db.tripDao.removeTripById(localId);
  }

  Future<void> _enqueue(String entity, String operation, int localId,
          Map<String, dynamic> payload) =>
      _db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        entityType: entity,
        operation: operation,
        localId: localId,
        payload: jsonEncode(payload),
        createdAt: Value(DateTime.now()),
      ));

  Stream<List<model.Trip>> watchAllTrips() {
    return _db
        .customSelect('SELECT id FROM trips',
            readsFrom: {_db.trips, _db.travelExpenses})
        .watch()
        .asyncMap((_) async {
          final tripRows = await _db.tripDao.getAllTrips();
          final trips = <model.Trip>[];
          for (final tripRow in tripRows) {
            final expenseRows =
                await _db.tripDao.getExpensesForTrip(tripRow.id);
            trips.add(_tripToModel(tripRow, expenseRows));
          }
          return trips;
        });
  }

  Future<model.Trip?> getTripWithExpenses(int tripId) async {
    final tripRow = await _db.tripDao.getById(tripId);
    if (tripRow == null) return null;
    final expenseRows = await _db.tripDao.getExpensesForTrip(tripId);
    return _tripToModel(tripRow, expenseRows);
  }

  Stream<model.Trip?> watchTripWithExpenses(int tripId) {
    return _db
        .customSelect('SELECT id FROM trips WHERE id = ?',
            variables: [Variable.withInt(tripId)],
            readsFrom: {_db.trips, _db.travelExpenses})
        .watch()
        .asyncMap((_) async {
          return getTripWithExpenses(tripId);
        });
  }

  Future<void> addTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String notes = '',
  }) async {
    await _serializeTrips(() async {
      await _db.transaction(() async {
        final localId = await _db.tripDao.insertTrip(TripsCompanion.insert(
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: Value(notes),
            createdAt: Value(DateTime.now())));
        await _enqueue('trip', 'create', localId, {
          'destination': destination,
          'start_date': AppDateUtils.formatDate(startDate),
          'end_date': AppDateUtils.formatDate(endDate),
          'notes': notes,
          'client_id': newPlanId(),
        });
      });
    });
    unawaited(flushTrips());
  }

  Future<void> deleteTrip(int localId) async {
    await _serializeTrips(() async {
      await _db.transaction(() async {
        final row = await _db.tripDao.getById(localId);
        final creation = (await _db.syncQueueDao.getPending())
            .where((q) =>
                q.entityType == 'trip' &&
                q.localId == localId &&
                q.operation == 'create')
            .firstOrNull;
        final clientId = creation == null
            ? null
            : (jsonDecode(creation.payload) as Map)['client_id'];
        await _removeTripData(localId);
        if (row?.remoteId == null && clientId != null) {
          await _enqueue('trip', 'delete', localId, {'client_id': clientId});
        }
        if (row?.remoteId != null) {
          await _enqueue(
              'trip', 'delete', localId, {'remote_id': row!.remoteId});
        }
      });
    });
    unawaited(flushTrips());
  }

  Future<void> _validateDestination(int tripId, String destinationId) async {
    if (destinationId.isEmpty) return;
    final row = await (_db.select(
      _db.tripPlans,
    )..where((p) => p.tripId.equals(tripId)))
        .getSingleOrNull();
    if (row == null ||
        !TripPlan.decode(
          row.content,
        ).destinations.any((d) => d.id == destinationId)) {
      throw StateError('Choose a destination in this trip.');
    }
  }

  Future<void> _validateLinks(int tripId, List<String> ids) async {
    final row = await (_db.select(_db.tripPlans)
          ..where((p) => p.tripId.equals(tripId)))
        .getSingleOrNull();
    final plan = row == null ? TripPlan() : TripPlan.decode(row.content);
    if (ids.toSet().length != ids.length ||
        ids.any((id) {
          final item = plan.find(id);
          return item == null ||
              !['activity', 'booking'].contains(item.kind) ||
              item['category'] == 'No accommodation needed';
        })) {
      throw StateError('Choose itinerary items in this trip.');
    }
  }

  Future<void> addTravelExpense({
    required int tripId,
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    String notes = '',
    String destinationId = '',
    List<String> planItemIds = const [],
  }) async {
    final rates = await _rateRepo.getCachedRates();
    final computed = CurrencyUtils.computeAmounts(amount, currency, rates);
    await _db.transaction(() async {
      await _validateDestination(tripId, destinationId);
      await _validateLinks(tripId, planItemIds);
      final trip = await _db.tripDao.getById(tripId);
      if (trip == null) throw StateError('Trip no longer exists.');
      final id =
          await _db.tripDao.insertTravelExpense(TravelExpensesCompanion.insert(
        tripId: tripId,
        clientId: Value(newPlanId()),
        tripRemoteId: Value(trip.remoteId),
        planItemIds: Value(jsonEncode(planItemIds)),
        destinationId: Value(destinationId),
        amount: amount,
        currency: currency,
        date: date,
        category: category,
        name: name,
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
        amountUsd: Value(computed['amount_usd']!),
        amountCny: Value(computed['amount_cny']!),
        amountHkd: Value(computed['amount_hkd']!),
        amountSgd: Value(computed['amount_sgd']!),
      ));
      await _queueExpense(id, tripId);
    });
    unawaited(flushExpenses());
  }

  Future<void> updateTravelExpense(
    int localId, {
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    String notes = '',
    String destinationId = '',
    List<String>? planItemIds,
  }) async {
    final rates = await _rateRepo.getCachedRates();
    final computed = CurrencyUtils.computeAmounts(amount, currency, rates);
    await _db.transaction(() async {
      final row = await (_db.select(_db.travelExpenses)
            ..where((e) => e.id.equals(localId)))
          .getSingleOrNull();
      if (row == null) throw StateError('Expense no longer exists.');
      final ids =
          planItemIds ?? (jsonDecode(row.planItemIds) as List).cast<String>();
      await _validateLinks(row.tripId, ids);
      await _validateDestination(row.tripId, destinationId);
      await _db.tripDao.updateTravelExpenseRow(
          localId,
          TravelExpensesCompanion(
            planItemIds: Value(jsonEncode(ids)),
            destinationId: Value(destinationId),
            amount: Value(amount),
            currency: Value(currency),
            date: Value(date),
            category: Value(category),
            name: Value(name),
            notes: Value(notes),
            synced: const Value(false),
            amountUsd: Value(computed['amount_usd']!),
            amountCny: Value(computed['amount_cny']!),
            amountHkd: Value(computed['amount_hkd']!),
            amountSgd: Value(computed['amount_sgd']!),
          ));
      await _queueExpense(localId, row.tripId);
    });
    unawaited(flushExpenses());
  }

  Future<void> _queueExpense(int id, int tripId) async {
    await (_db.delete(_db.syncQueue)
          ..where((q) =>
              q.entityType.equals('travel_expense') &
              q.localId.equals(id) &
              q.operation.isNotValue('delete')))
        .go();
    await _enqueue('travel_expense', 'update', id, {'trip_id': tripId});
  }

  Future<void> deleteTravelExpense(int localId, int tripId) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.travelExpenses)
            ..where((e) => e.id.equals(localId) & e.tripId.equals(tripId)))
          .getSingleOrNull();
      if (row == null) return;
      final trip = await _db.tripDao.getById(tripId);
      await (_db.delete(_db.syncQueue)
            ..where((q) =>
                q.entityType.equals('travel_expense') &
                q.localId.equals(localId)))
          .go();
      await _db.tripDao.removeTravelExpenseById(localId);
      if (row.remoteId != null && trip?.remoteId != null) {
        await _enqueue('travel_expense', 'delete', localId,
            {'remote_id': row.remoteId, 'trip_remote_id': trip!.remoteId});
      }
    });
    unawaited(flushExpenses());
  }

  Future<void>? _expensesRunning;
  bool _expensesAgain = false;
  Future<void> flushExpenses() {
    _expensesAgain = true;
    return _expensesRunning ??=
        _drainExpenses().whenComplete(() => _expensesRunning = null);
  }

  Future<void> _drainExpenses() async {
    if (_api == null) return;
    do {
      _expensesAgain = false;
      await flushTrips();
      final pending = (await _db.syncQueueDao.getPending())
          .where((q) => q.entityType == 'travel_expense');
      for (final op in pending) {
        try {
          final payload = jsonDecode(op.payload) as Map<String, dynamic>;
          if (op.operation == 'delete') {
            try {
              await _api.deleteTripExpense(payload['trip_remote_id'] as int,
                  payload['remote_id'] as int);
            } on DioException catch (e) {
              if (e.response?.statusCode != 404) rethrow;
            }
            await _db.syncQueueDao.removeById(op.id);
            continue;
          }
          final row = await (_db.select(_db.travelExpenses)
                ..where((e) => e.id.equals(op.localId)))
              .getSingleOrNull();
          if (row == null) {
            await _db.syncQueueDao.removeById(op.id);
            continue;
          }
          final trip = await _db.tripDao.getById(row.tripId);
          if (trip?.remoteId == null) continue;
          await preparePlan?.call(row.tripId);
          final plan = await (_db.select(_db.tripPlans)
                ..where((p) => p.tripId.equals(row.tripId)))
              .getSingleOrNull();
          if (plan?.dirty == true &&
              (row.planItemIds != '[]' || row.destinationId.isNotEmpty)) {
            continue;
          }
          final data = {
            'client_id': row.clientId,
            'plan_item_ids': jsonDecode(row.planItemIds),
            'destination_id': row.destinationId,
            'amount': row.amount,
            'currency': row.currency,
            'date': AppDateUtils.formatDate(row.date),
            'category': row.category,
            'name': row.name,
            'notes': row.notes,
          };
          final remoteId = row.remoteId ??
              (await _api.addTripExpense(trip!.remoteId!, data))['id'] as int;
          final exists = await _db.transaction(() async {
            final current = await (_db.select(_db.travelExpenses)
                  ..where((e) => e.id.equals(row.id)))
                .getSingleOrNull();
            if (current == null) {
              await _enqueue('travel_expense', 'delete', row.id,
                  {'trip_remote_id': trip!.remoteId, 'remote_id': remoteId});
              await _db.syncQueueDao.removeById(op.id);
              _expensesAgain = true;
              return false;
            }
            await _db.tripDao.updateTravelExpenseRow(
                row.id,
                TravelExpensesCompanion(
                    remoteId: Value(remoteId),
                    tripRemoteId: Value(trip!.remoteId)));
            return true;
          });
          if (!exists) continue;
          // PUT also covers a retried create whose original response was lost.
          await _api.updateTripExpense(trip!.remoteId!, remoteId, data);
          await _db.transaction(() async {
            final current = await (_db.select(_db.travelExpenses)
                  ..where((e) => e.id.equals(row.id)))
                .getSingleOrNull();
            if (current == null) {
              await _enqueue('travel_expense', 'delete', row.id,
                  {'trip_remote_id': trip.remoteId, 'remote_id': remoteId});
              _expensesAgain = true;
            } else {
              final stillPending = await (_db.select(_db.syncQueue)
                    ..where((q) => q.id.equals(op.id)))
                  .getSingleOrNull();
              await _db.tripDao.updateTravelExpenseRow(
                  row.id,
                  TravelExpensesCompanion(
                      remoteId: Value(remoteId),
                      tripRemoteId: Value(trip.remoteId),
                      synced: Value(stillPending != null)));
            }
            await _db.syncQueueDao.removeById(op.id);
          });
        } catch (e, st) {
          AppLogger.instance.log('Travel expense sync failed: $e',
              name: 'TravelRepo', error: e, stackTrace: st);
        }
      }
    } while (_expensesAgain);
  }

  Future<void> syncFromServer(String currency) =>
      _serializeTrips(() => _syncFromServer(currency));

  Future<void> _syncFromServer(String currency) async {
    final api = _api;
    if (api == null) return;
    try {
      await _flushTrips();
      final trips = await api.getTrips(currency: currency);
      final deleted = (await _db.syncQueueDao.getPending())
          .where((q) => q.entityType == 'trip' && q.operation == 'delete')
          .map((q) => (jsonDecode(q.payload) as Map)['remote_id'])
          .toSet();
      final deletedClients = (await _db.syncQueueDao.getPending())
          .where((q) => q.entityType == 'trip' && q.operation == 'delete')
          .map((q) => (jsonDecode(q.payload) as Map)['client_id'])
          .whereType<String>()
          .toSet();
      final remoteIds = trips.map((t) => t['id'] as int).toSet();
      for (final local in await _db.tripDao.getAllTrips()) {
        if (local.remoteId != null && !remoteIds.contains(local.remoteId)) {
          final plan = await (_db.select(_db.tripPlans)
                ..where((p) => p.tripId.equals(local.id)))
              .getSingleOrNull();
          if (plan?.dirty == true) {
            await (_db.update(_db.tripPlans)
                  ..where((p) => p.tripId.equals(local.id)))
                .write(const TripPlansCompanion(
                    syncError: Value(
                        'This trip was removed on the server. Your local plan is preserved.')));
          } else {
            await _db.transaction(() => _removeTripData(local.id));
          }
        }
      }
      for (final t in trips) {
        final remoteId = t['id'] as int;
        if (deleted.contains(remoteId) ||
            deletedClients.contains(t['client_id'])) {
          continue;
        }
        final existingTrip = await (_db.select(_db.trips)
              ..where((row) => row.remoteId.equals(remoteId)))
            .getSingleOrNull();
        if (existingTrip != null && !existingTrip.synced) continue;

        await _db.tripDao.upsertTripByRemoteId(
          TripsCompanion(
            remoteId: Value(remoteId),
            destination: Value(t['destination'] as String),
            startDate: Value(DateTime.parse(t['start_date'] as String)),
            endDate: Value(DateTime.parse(t['end_date'] as String)),
            notes: Value(t['notes'] as String? ?? ''),
            synced: const Value(true),
          ),
        );

        // Find the local trip to get its id
        final localTrip = await (_db.select(_db.trips)
              ..where((tr) => tr.remoteId.equals(remoteId)))
            .getSingleOrNull();
        if (localTrip == null) continue;

        final expenses =
            await api.getTripExpenses(remoteId, currency: currency);
        final deletedExpenses = (await _db.syncQueueDao.getPending())
            .where((q) =>
                q.entityType == 'travel_expense' && q.operation == 'delete')
            .map((q) => jsonDecode(q.payload)['remote_id'])
            .toSet();
        final serverExpenseIds = expenses.map((e) => e['id']).toSet();
        for (final local
            in await _db.tripDao.getExpensesForTrip(localTrip.id)) {
          if (local.synced &&
              local.remoteId != null &&
              !serverExpenseIds.contains(local.remoteId)) {
            await _db.tripDao.removeTravelExpenseById(local.id);
          }
        }
        for (final e in expenses) {
          if (deletedExpenses.contains(e['id'])) continue;
          final existingExp = await (_db.select(_db.travelExpenses)
                ..where((row) =>
                    row.remoteId.equals(e['id'] as int) |
                    row.clientId.equals(
                        e['client_id'] as String? ?? 'remote-${e['id']}')))
              .getSingleOrNull();
          if (existingExp != null && !existingExp.synced) continue;

          await _db.tripDao.upsertTravelExpenseByRemoteId(
            TravelExpensesCompanion(
              remoteId: Value(e['id'] as int),
              clientId: Value(e['client_id'] as String? ?? 'remote-${e['id']}'),
              planItemIds: Value(jsonEncode(e['plan_item_ids'] ?? [])),
              destinationId: Value(e['destination_id'] as String? ?? ''),
              tripId: Value(localTrip.id),
              tripRemoteId: Value(remoteId),
              amount: Value((e['amount'] as num).toDouble()),
              currency: Value(e['currency'] as String),
              date: Value(DateTime.parse(e['date'] as String)),
              category: Value(e['category'] as String),
              name: Value(e['name'] as String),
              notes: Value(e['notes'] as String? ?? ''),
              amountUsd: Value((e['amount_usd'] as num?)?.toDouble() ?? 0),
              amountCny: Value((e['amount_cny'] as num?)?.toDouble() ?? 0),
              amountHkd: Value((e['amount_hkd'] as num?)?.toDouble() ?? 0),
              amountSgd: Value((e['amount_sgd'] as num?)?.toDouble() ?? 0),
              synced: const Value(true),
            ),
          );
        }
      }
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
        clientId: row.clientId,
        planItemIds: (jsonDecode(row.planItemIds) as List).cast<String>(),
        destinationId: row.destinationId,
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
