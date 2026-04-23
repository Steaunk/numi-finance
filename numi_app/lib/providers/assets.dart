import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/account.dart' as model;
import '../models/balance_snapshot.dart' as model;
import 'core.dart';
import 'expenses.dart';

// --- Accounts + net worth ---

final accountListProvider = StreamProvider<List<model.Account>>((ref) {
  final currency = ref.watch(displayCurrencyProvider);
  return ref.watch(assetRepositoryProvider).watchAllAccounts(currency);
});

final netWorthProvider = FutureProvider<double>((ref) {
  final currency = ref.watch(displayCurrencyProvider);
  return ref.watch(assetRepositoryProvider).getNetWorth(currency);
});

final netWorthTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final currency = ref.watch(displayCurrencyProvider);
  return ref.watch(assetRepositoryProvider).getNetWorthTrend(currency);
});

final accountHistoryProvider =
    StreamProvider.family<List<model.BalanceSnapshot>, int>((ref, accountId) {
  return ref.watch(assetRepositoryProvider).watchAccountHistory(accountId);
});

// --- FIRE ---

final fireWithdrawalRateProvider = StateProvider<double>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getDouble('fire_withdrawal_rate') ??
      AppConstants.defaultFireRate;
});

final annualSpendingProvider = FutureProvider<double>((ref) async {
  final stats = await ref.watch(monthlyStatsProvider(null).future);
  final now = DateTime.now();
  // Last 12 complete months: e.g. if now is 2026-03, use 2025-03 ~ 2026-02
  final endMonth = DateTime(now.year, now.month - 1);
  final startMonth = DateTime(endMonth.year - 1, endMonth.month + 1);

  double total = 0;
  for (final entry in stats.entries) {
    final parts = entry.key.split('-');
    if (parts.length != 2) continue;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) continue;
    final monthDate = DateTime(y, m);
    if (!monthDate.isBefore(startMonth) && !monthDate.isAfter(endMonth)) {
      total += entry.value.values.fold<double>(0, (a, b) => a + b);
    }
  }
  return total;
});

typedef FireProgress = ({
  double annualSpending,
  double fireNumber,
  double netWorth,
  double progress,
  double runwayMonths,
});

final fireProgressProvider = FutureProvider<FireProgress>((ref) async {
  final annualSpending = await ref.watch(annualSpendingProvider.future);
  final netWorth = await ref.watch(netWorthProvider.future);
  final rate = ref.watch(fireWithdrawalRateProvider);
  final fireNumber = rate > 0 ? annualSpending / rate : 0.0;
  final progress = fireNumber > 0 ? netWorth / fireNumber : 0.0;
  final monthlySpending = annualSpending / 12;
  final runwayMonths = monthlySpending > 0 ? netWorth / monthlySpending : 0.0;
  return (
    annualSpending: annualSpending,
    fireNumber: fireNumber,
    netWorth: netWorth,
    progress: progress,
    runwayMonths: runwayMonths,
  );
});
