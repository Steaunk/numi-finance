import 'package:freezed_annotation/freezed_annotation.dart';

part 'balance_snapshot.freezed.dart';
part 'balance_snapshot.g.dart';

@freezed
class BalanceSnapshot with _$BalanceSnapshot {
  const factory BalanceSnapshot({
    required int id,
    required int accountId,
    required double balance,
    @Default(0) double change,
    required DateTime snapshotDate,
    @Default(0) double amountUsd,
    @Default(0) double amountCny,
    @Default(0) double amountHkd,
    @Default(0) double amountSgd,
  }) = _BalanceSnapshot;

  factory BalanceSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BalanceSnapshotFromJson(json);
}
