import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required int id,
    int? remoteId,
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String name,
    @Default('') String notes,
    @Default(0) double amountUsd,
    @Default(0) double amountCny,
    @Default(0) double amountHkd,
    @Default(0) double amountSgd,
    DateTime? createdAt,
    @Default(false) bool synced,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
