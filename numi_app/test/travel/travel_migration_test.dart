import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/data/local/database.dart';

void main() {
  test(
      'upgrading version 2 preserves existing trips, expenses and queued writes',
      () async {
    final directory = await Directory.systemTemp.createTemp('numi-migration-');
    final file = File('${directory.path}/test.db');
    var db = AppDatabase(NativeDatabase(file));
    final trip = await db.into(db.trips).insert(TripsCompanion.insert(
        destination: 'Existing trip',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12)));
    await db.into(db.travelExpenses).insert(TravelExpensesCompanion.insert(
        tripId: trip,
        amount: 25,
        currency: 'USD',
        date: DateTime(2026, 10, 10),
        category: 'Food & Drinks',
        name: 'Existing expense'));
    await db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        entityType: 'trip', operation: 'create', localId: trip, payload: '{}'));
    await db.close();
    // Restore the previous schema shape before opening it with migration v3.
    db = AppDatabase(NativeDatabase(file, setup: (raw) {
      raw.execute('DROP TABLE trip_plans');
      raw.execute('ALTER TABLE trips DROP COLUMN deleted');
      raw.execute('ALTER TABLE travel_expenses DROP COLUMN deleted');
      raw.execute('ALTER TABLE travel_expenses DROP COLUMN planner_entry_id');
      raw.execute('PRAGMA user_version = 2');
    }));
    expect(
        (await db.select(db.trips).getSingle()).destination, 'Existing trip');
    final expense = await db.select(db.travelExpenses).getSingle();
    expect(expense.amount, 25);
    expect(expense.plannerEntryId, '');
    expect(expense.deleted, false);
    expect(await db.select(db.tripPlans).get(), isEmpty);
    expect(await db.syncQueueDao.getPending(), hasLength(1));
    await db.close();
    await directory.delete(recursive: true);
  });
}
