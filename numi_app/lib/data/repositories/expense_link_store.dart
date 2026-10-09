import 'dart:convert';
import 'package:drift/drift.dart';
import '../../models/trip_plan.dart';
import '../local/database.dart';

/// Prune dangling references without creating, deleting or repricing expenses.
Future<void> reconcileExpenseLinks(
    AppDatabase db, int tripId, List<PlanItem> items) async {
  final ids = items
      .where((i) => i.kind == 'activity' || i.kind == 'booking')
      .map((i) => i.id)
      .toSet();
  final destinations =
      items.where((i) => i.kind == 'destination').map((i) => i.id).toSet();
  for (final row in await db.tripDao.getExpensesForTrip(tripId)) {
    final links = (jsonDecode(row.planItemIds) as List)
        .cast<String>()
        .where(ids.contains)
        .toList();
    await db.tripDao.updateTravelExpenseRow(
        row.id,
        TravelExpensesCompanion(
            planItemIds: Value(jsonEncode(links)),
            destinationId: Value(destinations.contains(row.destinationId)
                ? row.destinationId
                : '')));
  }
}
