import 'travel_expense.dart';

class Trip {
  final int id;
  final int? remoteId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String notes;
  final DateTime? createdAt;
  final bool synced;
  final List<TravelExpense> expenses;

  const Trip({
    required this.id,
    this.remoteId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.notes = '',
    this.createdAt,
    this.synced = false,
    this.expenses = const [],
  });
}
