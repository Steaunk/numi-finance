import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sync/sync_service.dart';
import 'assets.dart';
import 'core.dart';
import 'expenses.dart';

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
      _ref.invalidate(accountListProvider);
      _ref.invalidate(monthlyStatsProvider(null));
      _ref.invalidate(netWorthTrendProvider);
      _ref.invalidate(netWorthProvider);
      _ref.invalidate(categoriesProvider);
      // Portfolio cache is intentionally NOT invalidated here: fullSync does
      // not fetch portfolio data, so wiping the cache only forces an
      // unnecessary re-fetch on the next Portfolio screen open. The
      // PortfolioRepository has its own age-based stale-while-revalidate
      // logic, and pull-to-refresh on the Portfolio screens invalidates
      // explicitly when the user actually wants fresh data.
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
