class Account {
  final int id;
  final int? remoteId;
  final String name;
  final String currency;
  final double balance;
  final bool includeInTotal;
  final String notes;
  final String? apiUrl;
  final String? apiValuePath;
  final String? apiAuth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool synced;
  final double convertedBalance;

  const Account({
    required this.id,
    this.remoteId,
    required this.name,
    required this.currency,
    this.balance = 0,
    this.includeInTotal = true,
    this.notes = '',
    this.apiUrl,
    this.apiValuePath,
    this.apiAuth,
    this.createdAt,
    this.updatedAt,
    this.synced = false,
    this.convertedBalance = 0,
  });
}
