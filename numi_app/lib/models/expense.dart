class Expense {
  final int id;
  final int? remoteId;
  final double amount;
  final String currency;
  final DateTime date;
  final String category;
  final String name;
  final String notes;
  final double amountUsd;
  final double amountCny;
  final double amountHkd;
  final double amountSgd;
  final DateTime? createdAt;
  final bool synced;

  const Expense({
    required this.id,
    this.remoteId,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    required this.name,
    this.notes = '',
    this.amountUsd = 0,
    this.amountCny = 0,
    this.amountHkd = 0,
    this.amountSgd = 0,
    this.createdAt,
    this.synced = false,
  });
}
