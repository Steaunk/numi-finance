import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../data/local/database.dart';
import '../data/remote/api_client.dart';
import '../data/remote/endpoints/expense_api.dart';
import '../data/remote/endpoints/travel_api.dart';
import '../data/remote/endpoints/asset_api.dart';
import '../data/remote/endpoints/rate_api.dart';
import '../data/remote/endpoints/portfolio_api.dart';
import '../data/remote/endpoints/version_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/travel_repository.dart';
import '../data/repositories/asset_repository.dart';
import '../data/repositories/rate_repository.dart';
import '../data/repositories/portfolio_repository.dart';
import '../models/portfolio.dart';
import '../data/sync/sync_service.dart';
import '../models/expense.dart' as model;
import '../models/trip.dart' as model;
import '../models/account.dart' as model;
import '../models/balance_snapshot.dart' as model;
import '../config/constants.dart';

// --- Foundation ---

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final serverUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('server_url') ?? '';
});

final nginxUsernameProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('nginx_username') ?? '';
});

final nginxPasswordProvider = StateProvider<String>((ref) {
  return ref.watch(sharedPrefsProvider).getString('nginx_password') ?? '';
});

/// Returns {htmlUrl, assetApiUrl} if a newer build is available, else null.
final updateCheckProvider =
    FutureProvider<({String htmlUrl, String assetApiUrl})?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final latest = await VersionApi().getLatestRelease();
    if (latest == null || latest.buildNumber <= currentBuild) return null;
    return (htmlUrl: latest.htmlUrl, assetApiUrl: latest.assetApiUrl);
  } catch (_) {
    return null;
  }
});

final displayCurrencyProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('display_currency') ?? AppConstants.defaultCurrency;
});

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// --- Biometric Auth ---

final biometricEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getBool('biometric_enabled') ?? false;
});

final biometricAuthenticatedProvider = StateProvider<bool>((ref) => false);

final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  return await auth.canCheckBiometrics || await auth.isDeviceSupported();
});

// --- API Client ---

final apiClientProvider = Provider<ApiClient?>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url.isEmpty) return null;
  final username = ref.watch(nginxUsernameProvider);
  final password = ref.watch(nginxPasswordProvider);
  return ApiClient(
    url,
    username: username.isEmpty ? null : username,
    password: password.isEmpty ? null : password,
  );
});

final expenseApiProvider = Provider<ExpenseApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client != null ? ExpenseApi(client) : null;
});

final travelApiProvider = Provider<TravelApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client != null ? TravelApi(client) : null;
});

final assetApiProvider = Provider<AssetApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client != null ? AssetApi(client) : null;
});

final rateApiProvider = Provider<RateApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client != null ? RateApi(client) : null;
});

final portfolioApiProvider = Provider<PortfolioApi?>((ref) {
  final client = ref.watch(apiClientProvider);
  return client != null ? PortfolioApi(client) : null;
});

// --- Repositories ---

final rateRepositoryProvider = Provider<RateRepository>((ref) {
  return RateRepository(
    ref.watch(databaseProvider),
    ref.watch(rateApiProvider),
  );
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(expenseApiProvider),
    ref.watch(rateRepositoryProvider),
  );
});

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepository(
    ref.watch(databaseProvider),
    ref.watch(travelApiProvider),
    ref.watch(rateRepositoryProvider),
  );
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(
    ref.watch(databaseProvider),
    ref.watch(assetApiProvider),
    ref.watch(rateRepositoryProvider),
  );
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.watch(portfolioApiProvider));
});

// --- Sync ---

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return SyncService(
    db: ref.watch(databaseProvider),
    expenseApi: ref.watch(expenseApiProvider)!,
    travelApi: ref.watch(travelApiProvider)!,
    assetApi: ref.watch(assetApiProvider)!,
    expenseRepo: ref.watch(expenseRepositoryProvider),
    travelRepo: ref.watch(travelRepositoryProvider),
    assetRepo: ref.watch(assetRepositoryProvider),
    rateRepo: ref.watch(rateRepositoryProvider),
    prefs: ref.watch(sharedPrefsProvider),
  );
});

final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<void>>((ref) {
  return SyncStateNotifier(ref);
});

class SyncStateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SyncStateNotifier(this._ref) : super(const AsyncData(null));

  Future<void> syncNow() async {
    final service = _ref.read(syncServiceProvider);
    if (service == null) return;
    state = const AsyncLoading();
    try {
      final currency = _ref.read(displayCurrencyProvider);
      await service.fullSync(currency);
      state = const AsyncData(null);
      // Invalidate data providers so UI re-reads from local DB
      _ref.invalidate(accountListProvider);
      _ref.invalidate(monthlyStatsProvider(null));
      _ref.invalidate(netWorthTrendProvider);
      _ref.invalidate(netWorthProvider);
      _ref.invalidate(categoriesProvider);
      // Invalidate portfolio providers so charts refresh with latest data
      _ref.read(portfolioRepositoryProvider).invalidateCache();
      _ref.invalidate(portfolioSummaryProvider);
      _ref.invalidate(portfolioHistoryProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final pendingCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).syncQueueDao.watchPendingCount();
});

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

// --- Expense Providers ---

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

// --- Travel Providers ---

final tripListProvider = StreamProvider<List<model.Trip>>((ref) {
  return ref.watch(travelRepositoryProvider).watchAllTrips();
});

final tripDetailProvider =
    StreamProvider.family<model.Trip?, int>((ref, tripId) {
  return ref.watch(travelRepositoryProvider).watchTripWithExpenses(tripId);
});

// --- Asset Providers ---

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

// --- FIRE Providers ---

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

// --- Rates ---

final cachedRatesProvider = FutureProvider<Map<String, double>>((ref) {
  return ref.watch(rateRepositoryProvider).getCachedRates();
});

// --- Portfolio Providers ---

final portfolioSummaryProvider = FutureProvider<PortfolioSummary?>((ref) {
  return ref.watch(portfolioRepositoryProvider).getPortfolioSummary();
});

final portfolioHistoryProvider =
    FutureProvider.family<List<PortfolioHistorySnapshot>, int>((ref, days) {
  return ref.watch(portfolioRepositoryProvider).getPortfolioHistory(days: days);
});

final stockHistoryProvider = FutureProvider.family<List<StockHistoryPoint>,
    ({String code, int days})>((ref, params) {
  return ref
      .watch(portfolioRepositoryProvider)
      .getStockHistory(params.code, days: params.days);
});
