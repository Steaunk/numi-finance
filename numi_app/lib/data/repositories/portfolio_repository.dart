import 'dart:async';

import '../../models/portfolio.dart';
import '../remote/endpoints/portfolio_api.dart';

/// Callback invoked when a background refresh has updated the cache.
typedef OnCacheUpdated = void Function();

class PortfolioRepository {
  final PortfolioApi? _api;
  OnCacheUpdated? onCacheUpdated;

  static const _maxCacheAge = Duration(days: 7);

  // Summary cache
  PortfolioSummary? _cachedSummary;
  DateTime? _summaryFetchTime;

  // History caches: key = "code:days" or days
  final Map<String, (List<StockHistoryPoint>, DateTime)> _historyCache = {};
  final Map<int, (List<PortfolioHistorySnapshot>, DateTime)> _portfolioHistoryCache = {};

  PortfolioRepository(this._api);

  /// Soft refresh threshold — after this, serve cache but refresh in background.
  Duration _refreshThreshold(int days) {
    if (days <= 7) return const Duration(hours: 1);
    if (days <= 30) return const Duration(hours: 4);
    return const Duration(days: 1);
  }

  // --- Portfolio Summary ---

  Future<PortfolioSummary?> getPortfolioSummary() async {
    if (_api == null) return null;
    final hasCache = _cachedSummary != null && _summaryFetchTime != null;
    final age = hasCache ? DateTime.now().difference(_summaryFetchTime!) : _maxCacheAge;

    if (hasCache && age < _maxCacheAge) {
      // Serve cache; background refresh if stale
      if (age > const Duration(minutes: 2)) {
        _refreshSummaryInBackground();
      }
      return _cachedSummary;
    }
    // No cache or expired — fetch synchronously
    return _fetchSummary();
  }

  Future<PortfolioSummary?> _fetchSummary() async {
    try {
      final results = await Future.wait([
        _api!.getHoldings(),
        _api.getAccount(),
      ]);
      final summary = PortfolioSummary.fromJson(
        results[0],
        accountJson: results[1],
      );
      _cachedSummary = summary;
      _summaryFetchTime = DateTime.now();
      return summary;
    } catch (_) {
      return _cachedSummary; // fallback to stale cache on error
    }
  }

  void _refreshSummaryInBackground() {
    unawaited(_fetchSummary().then((s) {
      if (s != null) onCacheUpdated?.call();
    }));
  }

  // --- Portfolio History ---

  Future<List<PortfolioHistorySnapshot>> getPortfolioHistory({
    int days = 30,
  }) async {
    if (_api == null) return [];
    final cached = _portfolioHistoryCache[days];
    final hasCache = cached != null;
    final age = hasCache ? DateTime.now().difference(cached.$2) : _maxCacheAge;

    if (hasCache && age < _maxCacheAge) {
      if (age > _refreshThreshold(days)) {
        _refreshPortfolioHistoryInBackground(days);
      }
      return cached.$1;
    }
    return _fetchPortfolioHistory(days);
  }

  Future<List<PortfolioHistorySnapshot>> _fetchPortfolioHistory(int days) async {
    try {
      final json = await _api!.getHistory(days: days);
      final records = json['history'] as List? ?? [];
      final snapshots = records.map((r) {
        return PortfolioHistorySnapshot(
          timestamp: DateTime.parse(r['timestamp'] as String),
          totalUsd: (r['usd_market_val'] as num?)?.toDouble() ?? 0,
          pnl: (r['pnl'] as num?)?.toDouble() ?? 0,
        );
      }).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _portfolioHistoryCache[days] = (snapshots, DateTime.now());
      return snapshots;
    } catch (_) {
      return _portfolioHistoryCache[days]?.$1 ?? [];
    }
  }

  void _refreshPortfolioHistoryInBackground(int days) {
    unawaited(_fetchPortfolioHistory(days).then((s) {
      if (s.isNotEmpty) onCacheUpdated?.call();
    }));
  }

  // --- Stock History ---

  Future<List<StockHistoryPoint>> getStockHistory(
    String code, {
    int days = 30,
  }) async {
    if (_api == null) return [];
    final cacheKey = '$code:$days';
    final cached = _historyCache[cacheKey];
    final hasCache = cached != null;
    final age = hasCache ? DateTime.now().difference(cached.$2) : _maxCacheAge;

    if (hasCache && age < _maxCacheAge) {
      if (age > _refreshThreshold(days)) {
        _refreshStockHistoryInBackground(cacheKey, code, days);
      }
      return cached.$1;
    }
    return _fetchStockHistory(cacheKey, code, days);
  }

  Future<List<StockHistoryPoint>> _fetchStockHistory(
      String cacheKey, String code, int days) async {
    try {
      final json = await _api!.getStockHistory(code, days: days);
      final history = (json['history'] as List? ?? [])
          .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
          .toList();
      _historyCache[cacheKey] = (history, DateTime.now());
      return history;
    } catch (_) {
      return _historyCache[cacheKey]?.$1 ?? [];
    }
  }

  void _refreshStockHistoryInBackground(
      String cacheKey, String code, int days) {
    unawaited(_fetchStockHistory(cacheKey, code, days).then((s) {
      if (s.isNotEmpty) onCacheUpdated?.call();
    }));
  }

  // --- Cache management ---

  void invalidateCache() {
    _cachedSummary = null;
    _summaryFetchTime = null;
    _historyCache.clear();
    _portfolioHistoryCache.clear();
  }
}
