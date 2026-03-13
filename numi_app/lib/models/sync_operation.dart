class SyncOperation {
  final int id;
  final String entityType;
  final String operation;
  final int localId;
  final String payload;
  final DateTime? createdAt;
  final int retryCount;

  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.localId,
    required this.payload,
    this.createdAt,
    this.retryCount = 0,
  });
}
