import 'package:intl/intl.dart';

class AppDateUtils {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _monthFormat = DateFormat('yyyy-MM');
  static final _displayDate = DateFormat('MMM d, yyyy');
  static final _displayMonth = DateFormat('MMM yyyy');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatMonth(DateTime date) => _monthFormat.format(date);
  static String displayDate(DateTime date) => _displayDate.format(date);
  static String displayMonth(DateTime date) => _displayMonth.format(date);

  static DateTime parseDate(String date) => _dateFormat.parse(date);
  static DateTime parseMonth(String month) => _monthFormat.parse(month);

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// Get previous month
  static DateTime previousMonth(DateTime date) {
    return DateTime(date.year, date.month - 1, 1);
  }

  /// Get next month
  static DateTime nextMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 1);
  }
}
