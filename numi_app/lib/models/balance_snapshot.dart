class BalanceSnapshot {
  final int id;
  final int accountId;
  final double balance;
  final double change;
  final DateTime snapshotDate;
  final double amountUsd;
  final double amountCny;
  final double amountHkd;
  final double amountSgd;

  const BalanceSnapshot({
    required this.id,
    required this.accountId,
    required this.balance,
    this.change = 0,
    required this.snapshotDate,
    this.amountUsd = 0,
    this.amountCny = 0,
    this.amountHkd = 0,
    this.amountSgd = 0,
  });
}
