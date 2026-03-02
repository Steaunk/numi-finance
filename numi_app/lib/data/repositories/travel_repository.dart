import 'dart:convert';
import 'package:drift/drift.dart';
import '../../models/travel_expense.dart' as model;
import '../../models/trip.dart' as model;
import '../../utils/currency_utils.dart';
import '../local/database.dart';
import '../remote/endpoints/travel_api.dart';

class TravelRepository {
  final AppDatabase _db;
  final TravelApi? _api;

  TravelRepository(this._db, this._api);

  Stream<List<model.Trip>> watchAllTrips() {
    return _db.tripDao.watchAll().asyncMap((tripRows) async {
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

  Future<void> addTrip({
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String notes = '',
  }) async {
    final companion = TripsCompanion.insert(
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      notes: Value(notes),
      createdAt: Value(DateTime.now()),
    );
    final localId = await _db.tripDao.insertTrip(companion);

    final api = _api;
    if (api != null) {
      try {
        final remote = await api.addTrip({
          'destination': destination,
          'start_date':
              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
          'end_date':
              '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
          'notes': notes,
        });
        await (_db.update(_db.trips)..where((t) => t.id.equals(localId)))
            .write(TripsCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
      } catch (_) {
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'trip',
            operation: 'create',
            localId: localId,
            payload: jsonEncode({
              'destination': destination,
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'notes': notes,
            }),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> deleteTrip(int localId) async {
    final row = await _db.tripDao.getById(localId);
    await _db.tripDao.removeTripById(localId);

    final api = _api;
    if (api != null && row?.remoteId != null) {
      try {
        await api.deleteTrip(row!.remoteId!);
      } catch (_) {}
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
  }) async {
    final rates = await _getCachedRates();
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

    final api = _api;
    if (api != null && tripRow?.remoteId != null) {
      try {
        final remote = await api.addTripExpense(tripRow!.remoteId!, {
          'amount': amount,
          'currency': currency,
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
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
      } catch (_) {
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'travel_expense',
            operation: 'create',
            localId: localId,
            payload: jsonEncode({
              'trip_id': tripId,
              'amount': amount,
              'currency': currency,
              'date': date.toIso8601String(),
              'category': category,
              'name': name,
              'notes': notes,
            }),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
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
      } catch (_) {}
    }
  }

  Future<void> syncFromServer(String currency) async {
    final api = _api;
    if (api == null) return;
    try {
      final trips = await api.getTrips(currency: currency);
      for (final t in trips) {
        final remoteId = t['id'] as int;
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

        final expenses = await api.getTripExpenses(remoteId, currency: currency);
        for (final e in expenses) {
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
    } catch (_) {}
  }

  Future<Map<String, double>> _getCachedRates() async {
    final rate = await _db.exchangeRateDao.getLatest();
    if (rate != null) {
      return {'cny': rate.cny, 'hkd': rate.hkd, 'sgd': rate.sgd, 'jpy': rate.jpy};
    }
    return {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0};
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
