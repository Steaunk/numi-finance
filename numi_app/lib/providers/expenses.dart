import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart' as model;
import 'core.dart';

final expenseListProvider =
    StreamProvider.family<List<model.Expense>, DateTime>((ref, month) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchByMonth(month.year, month.month);
});

final categoriesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(expenseRepositoryProvider).getCategories();
});

final monthlyStatsProvider =
    FutureProvider.family<Map<String, Map<String, double>>, int?>((ref, year) {
  final currency = ref.watch(displayCurrencyProvider);
  return ref
      .watch(expenseRepositoryProvider)
      .getMonthlyStats(year: year, displayCurrency: currency);
});
