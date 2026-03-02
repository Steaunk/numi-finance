import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_operation.freezed.dart';
part 'sync_operation.g.dart';

@freezed
class SyncOperation with _$SyncOperation {
  const factory SyncOperation({
    required int id,
    required String entityType, // "expense", "trip", "travel_expense", "account"
    required String operation, // "create", "update", "delete"
    required int localId,
    required String payload, // JSON-serialized request body
    DateTime? createdAt,
    @Default(0) int retryCount,
  }) = _SyncOperation;

  factory SyncOperation.fromJson(Map<String, dynamic> json) =>
      _$SyncOperationFromJson(json);
}
