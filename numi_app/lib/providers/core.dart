import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/constants.dart';
import '../data/cache_store.dart';
import '../data/local/database.dart';
import '../data/remote/api_client.dart';
import '../data/remote/endpoints/asset_api.dart';
import '../data/remote/endpoints/expense_api.dart';
import '../data/remote/endpoints/portfolio_api.dart';
import '../data/remote/endpoints/rate_api.dart';
import '../data/remote/endpoints/travel_api.dart';
import '../data/remote/endpoints/version_api.dart';
import '../data/repositories/asset_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/portfolio_repository.dart';
import '../data/repositories/rate_repository.dart';
import '../data/repositories/travel_repository.dart';

// --- Foundation ---

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final serverUrlProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('server_url') ?? '';
});

// Initialised from secure storage in main.dart
final nginxUsernameProvider = StateProvider<String>((ref) => '');
final nginxPasswordProvider = StateProvider<String>((ref) => '');

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

// --- API Client + endpoints ---

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

final cacheStoreProvider = Provider<CacheStore>((ref) {
  return CacheStore(ref.watch(sharedPrefsProvider));
});

/// Bumped when portfolio background refresh completes, triggering re-fetch.
final portfolioRefreshCounter = StateProvider<int>((ref) => 0);

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  final repo = PortfolioRepository(
    ref.watch(portfolioApiProvider),
    ref.watch(cacheStoreProvider),
  );
  repo.onUpdate.listen((_) {
    ref.read(portfolioRefreshCounter.notifier).update((v) => v + 1);
  });
  return repo;
});

// --- Rates ---

final cachedRatesProvider = FutureProvider<Map<String, double>>((ref) {
  return ref.watch(rateRepositoryProvider).getCachedRates();
});
