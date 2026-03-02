import 'package:freezed_annotation/freezed_annotation.dart';

part 'travel_expense.freezed.dart';
part 'travel_expense.g.dart';

@freezed
class TravelExpense with _$TravelExpense {
  const factory TravelExpense({
    required int id,
    int? remoteId,
    required int tripId,
    int? tripRemoteId,
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
  }) = _TravelExpense;

  factory TravelExpense.fromJson(Map<String, dynamic> json) =>
      _$TravelExpenseFromJson(json);
}
