import 'dart:convert';
import 'package:drift/drift.dart';
import '../../models/trip_plan.dart';
import '../../utils/currency_utils.dart';
import '../local/database.dart';
import 'rate_repository.dart';

/// Called inside the same transaction that saves a planning document.
Future<void> reconcileBookingPayments(
    AppDatabase db, int tripId, List<PlanItem> items,
    {Map<String, dynamic>? serverIds}) async {
  final bookings = {
    for (final i in items)
      if (i.kind == 'booking' || i.kind == 'activity') i.id: i
  };
  final trip = await db.tripDao.getById(tripId);
  if (trip == null) return;
  final rates = await RateRepository(db, null).getCachedRates();
  final rows = await db.tripDao.getExpensesForTrip(tripId);
  for (final row in rows.where((e) => e.planItemId != null)) {
    final booking = bookings[row.planItemId];
    if (booking == null) {
      if (serverIds != null &&
          !serverIds.containsKey(row.clientId) &&
          !serverIds.values.contains(row.remoteId)) {
        await db.tripDao.removeTravelExpenseById(row.id);
      } else {
        final remoteId = serverIds?[row.clientId] as int? ?? row.remoteId;
        await db.tripDao.updateTravelExpenseRow(
            row.id,
            TravelExpensesCompanion(
                planItemId: const Value(null),
                remoteId: Value(remoteId),
                synced: Value(remoteId != null)));
        if (remoteId == null) {
          await db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
              entityType: 'travel_expense',
              operation: 'create',
              localId: row.id,
              payload: jsonEncode({
                'trip_id': tripId,
                'client_id': row.clientId,
                'amount': row.amount,
                'currency': row.currency,
                'date': planDate(row.date),
                'category': row.category,
                'name': row.name,
                'notes': row.notes
              })));
        }
      }
    } else if (booking['paymentStatus'] != 'paid') {
      await db.tripDao.removeTravelExpenseById(row.id);
    }
  }
  final identities = <String>{};
  for (final booking
      in bookings.values.where((b) => b['paymentStatus'] == 'paid')) {
    final clientId = booking['expenseClientId'];
    final amount = double.tryParse(booking['amount']);
    final date = DateTime.tryParse(booking['paidDate']);
    if (clientId.isEmpty ||
        !identities.add(clientId) ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        date == null ||
        booking['currency'].isEmpty) {
      throw StateError('Enter a valid amount, currency and payment date.');
    }
    final legacyRemote = clientId.startsWith('remote-')
        ? int.tryParse(clientId.substring(7))
        : null;
    final existing = await (db.select(db.travelExpenses)
          ..where((e) =>
              e.clientId.equals(clientId) |
              (legacyRemote == null
                  ? const Constant(false)
                  : e.remoteId.equals(legacyRemote))))
        .getSingleOrNull();
    if (existing != null &&
        (existing.tripId != tripId ||
            (existing.planItemId != null &&
                existing.planItemId != booking.id))) {
      throw StateError('This expense is already linked to another itinerary item.');
    }
    final changed = existing == null ||
        existing.amount != amount ||
        existing.currency != booking['currency'];
    final converted =
        CurrencyUtils.computeAmounts(amount, booking['currency'], rates);
    final entry = TravelExpensesCompanion(
        tripId: Value(tripId),
        tripRemoteId: Value(trip.remoteId),
        clientId: Value(clientId),
        planItemId: Value(booking.id),
        remoteId: Value(serverIds?[clientId] as int? ?? existing?.remoteId),
        amount: Value(amount),
        currency: Value(booking['currency']),
        date: Value(date),
        name: Value(TripPlan(items: items).itemTitle(booking)),
        notes: Value(booking['notes']),
        category: Value(booking['expenseCategory']),
        amountUsd:
            Value(changed ? converted['amount_usd']! : existing.amountUsd),
        amountCny:
            Value(changed ? converted['amount_cny']! : existing.amountCny),
        amountHkd:
            Value(changed ? converted['amount_hkd']! : existing.amountHkd),
        amountSgd:
            Value(changed ? converted['amount_sgd']! : existing.amountSgd),
        createdAt: Value(existing?.createdAt ?? DateTime.now()),
        // The document's revision/mutation is the sync authority for this row.
        synced: const Value(true));
    if (existing == null) {
      await db.into(db.travelExpenses).insert(entry);
    } else {
      await db.tripDao.updateTravelExpenseRow(existing.id, entry);
      await (db.delete(db.syncQueue)
            ..where((q) =>
                q.entityType.equals('travel_expense') &
                q.localId.equals(existing.id)))
          .go();
    }
  }
}
