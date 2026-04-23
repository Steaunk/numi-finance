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
      await _ref.read(portfolioRepositoryProvider).invalidateCache();
      _ref.read(portfolioRefreshCounter.notifier).update((v) => v + 1);
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
