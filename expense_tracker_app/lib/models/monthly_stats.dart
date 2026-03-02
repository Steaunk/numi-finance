import 'package:freezed_annotation/freezed_annotation.dart';

part 'monthly_stats.freezed.dart';
part 'monthly_stats.g.dart';

@freezed
class MonthlyStats with _$MonthlyStats {
  const factory MonthlyStats({
    required Map<String, Map<String, double>> months,
    // month string (YYYY-MM) -> category -> amount
  }) = _MonthlyStats;

  factory MonthlyStats.fromJson(Map<String, dynamic> json) =>
      _$MonthlyStatsFromJson(json);
}
