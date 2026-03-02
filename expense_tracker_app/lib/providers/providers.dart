import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local/database.dart';
import '../data/remote/api_client.dart';
import '../data/remote/endpoints/expense_api.dart';
import '../data/remote/endpoints/travel_api.dart';
import '../data/remote/endpoints/asset_api.dart';
import '../data/remote/endpoints/rate_api.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/travel_repository.dart';
import '../data/repositories/asset_repository.dart';
import '../data/repositories/rate_repository.dart';
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
  return prefs.getString('server_url') ?? 'https://your-server.com';
});

final displayCurrencyProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('display_currency') ?? AppConstants.defaultCurrency;
});

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// --- API Client ---

final apiClientProvider = Provider<ApiClient?>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url.isEmpty) return null;
  return ApiClient(url);
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

// --- Repositories ---

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(expenseApiProvider),
  );
});

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepository(
    ref.watch(databaseProvider),
    ref.watch(travelApiProvider),
  );
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(
    ref.watch(databaseProvider),
    ref.watch(assetApiProvider),
  );
});

final rateRepositoryProvider = Provider<RateRepository>((ref) {
  return RateRepository(
    ref.watch(databaseProvider),
    ref.watch(rateApiProvider),
  );
});

// --- Sync ---

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(apiClientProvider);
  if (client == null) return null;
  return SyncService(
    db: ref.watch(databaseProvider),
    apiClient: client,
    expenseApi: ref.watch(expenseApiProvider)!,
    travelApi: ref.watch(travelApiProvider)!,
    assetApi: ref.watch(assetApiProvider)!,
    expenseRepo: ref.watch(expenseRepositoryProvider),
    travelRepo: ref.watch(travelRepositoryProvider),
    assetRepo: ref.watch(assetRepositoryProvider),
    rateRepo: ref.watch(rateRepositoryProvider),
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
    FutureProvider.family<model.Trip?, int>((ref, tripId) {
  return ref.watch(travelRepositoryProvider).getTripWithExpenses(tripId);
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
