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

  TravelRepository(this._db, this._api, this._rateRepo);

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

  Future<void> addTravelExpense({
    required int tripId,
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    String notes = '',
  }) async {
    final rates = await _rateRepo.getCachedRates();
    final computed = CurrencyUtils.computeAmounts(amount, currency, rates);

    final tripRow = await _db.tripDao.getById(tripId);
    final companion = TravelExpensesCompanion.insert(
      tripId: tripId,
      tripRemoteId: Value(tripRow?.remoteId),
      amount: amount,
      currency: currency,
      date: date,
      category: category,
      name: name,
      notes: Value(notes),
      amountUsd: Value(computed['amount_usd']!),
      amountCny: Value(computed['amount_cny']!),
      amountHkd: Value(computed['amount_hkd']!),
      amountSgd: Value(computed['amount_sgd']!),
      createdAt: Value(DateTime.now()),
    );
    final localId = await _db.tripDao.insertTravelExpense(companion);
    if (_api == null || tripRow?.remoteId == null) {
      await _enqueue('travel_expense', 'create', localId, {
        'trip_id': tripId,
        'amount': amount,
        'currency': currency,
        'date': AppDateUtils.formatDate(date),
        'category': category,
        'name': name,
        'notes': notes,
      });
      return;
    }

    final api = _api;
    if (tripRow?.remoteId != null) {
      try {
        final remote = await api.addTripExpense(tripRow!.remoteId!, {
          'amount': amount,
          'currency': currency,
          'date': AppDateUtils.formatDate(date),
          'category': category,
          'name': name,
          'notes': notes,
        });
        await (_db.update(_db.travelExpenses)
              ..where((e) => e.id.equals(localId)))
            .write(TravelExpensesCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
      } catch (e, st) {
        AppLogger.instance.log('addTravelExpense push failed: $e',
            name: 'TravelRepo', error: e, stackTrace: st);
        await _enqueue('travel_expense', 'create', localId, {
          'trip_id': tripId,
          'amount': amount,
          'currency': currency,
          'date': date.toIso8601String(),
          'category': category,
          'name': name,
          'notes': notes,
        });
      }
    }
  }

  Future<void> updateTravelExpense(
    int localId, {
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    String notes = '',
  }) async {
    final rates = await _rateRepo.getCachedRates();
    final computed = CurrencyUtils.computeAmounts(amount, currency, rates);

    await _db.tripDao.updateTravelExpenseRow(
      localId,
      TravelExpensesCompanion(
        amount: Value(amount),
        currency: Value(currency),
        date: Value(date),
        category: Value(category),
        name: Value(name),
        notes: Value(notes),
        amountUsd: Value(computed['amount_usd']!),
        amountCny: Value(computed['amount_cny']!),
        amountHkd: Value(computed['amount_hkd']!),
        amountSgd: Value(computed['amount_sgd']!),
        synced: const Value(false),
      ),
    );

    final pushed = await _pushTravelExpense(
        localId, amount, currency, date, category, name, notes);
    if (!pushed) {
      final row = await (_db.select(_db.travelExpenses)
            ..where((e) => e.id.equals(localId)))
          .getSingleOrNull();
      await _enqueue('travel_expense', 'update', localId, {
        'trip_id': row?.tripId,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        'category': category,
        'name': name,
        'notes': notes,
      });
    }
  }

  Future<bool> _pushTravelExpense(
    int localId,
    double amount,
    String currency,
    DateTime date,
    String category,
    String name,
    String notes,
  ) async {
    final api = _api;
    final row = await (_db.select(_db.travelExpenses)
          ..where((e) => e.id.equals(localId)))
        .getSingleOrNull();
    if (api == null ||
        row == null ||
        row.remoteId == null ||
        row.tripRemoteId == null) {
      return false;
    }
    try {
      await api.updateTripExpense(row.tripRemoteId!, row.remoteId!, {
        'amount': amount,
        'currency': currency,
        'date': AppDateUtils.formatDate(date),
        'category': category,
        'name': name,
        'notes': notes,
      });
      await (_db.update(_db.travelExpenses)..where((e) => e.id.equals(localId)))
          .write(const TravelExpensesCompanion(synced: Value(true)));
      return true;
    } catch (e, st) {
      AppLogger.instance.log('updateTravelExpense push failed: $e',
          name: 'TravelRepo', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> deleteTravelExpense(int localId, int tripId) async {
    final row = await (_db.select(_db.travelExpenses)
          ..where((e) => e.id.equals(localId)))
        .getSingleOrNull();
    await _db.tripDao.removeTravelExpenseById(localId);

    final tripRow = await _db.tripDao.getById(tripId);
    final api = _api;
    if (api != null && row?.remoteId != null && tripRow?.remoteId != null) {
      try {
        await api.deleteTripExpense(tripRow!.remoteId!, row!.remoteId!);
      } catch (e, st) {
        AppLogger.instance.log('deleteTravelExpense push failed: $e',
            name: 'TravelRepo', error: e, stackTrace: st);
        await _enqueue('travel_expense', 'delete', localId, {
          'remote_id': row!.remoteId,
          'trip_remote_id': tripRow!.remoteId,
        });
      }
    }
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
        for (final e in expenses) {
          final existingExp = await (_db.select(_db.travelExpenses)
                ..where((row) => row.remoteId.equals(e['id'] as int)))
              .getSingleOrNull();
          if (existingExp != null && !existingExp.synced) continue;

          await _db.tripDao.upsertTravelExpenseByRemoteId(
            TravelExpensesCompanion(
              remoteId: Value(e['id'] as int),
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
