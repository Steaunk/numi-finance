import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

@freezed
class Account with _$Account {
  const factory Account({
    required int id,
    int? remoteId,
    required String name,
    required String currency,
    @Default(0) double balance,
    @Default(true) bool includeInTotal,
    @Default('') String notes,
    String? apiUrl,
    String? apiValuePath,
    String? apiAuth,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool synced,
    // Display fields (not stored)
    @Default(0) double convertedBalance,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}
