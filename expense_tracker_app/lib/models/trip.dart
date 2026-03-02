import 'package:freezed_annotation/freezed_annotation.dart';
import 'travel_expense.dart';

part 'trip.freezed.dart';
part 'trip.g.dart';

@freezed
class Trip with _$Trip {
  const factory Trip({
    required int id,
    int? remoteId,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    @Default('') String notes,
    DateTime? createdAt,
    @Default(false) bool synced,
    @Default([]) List<TravelExpense> expenses,
  }) = _Trip;

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
}
