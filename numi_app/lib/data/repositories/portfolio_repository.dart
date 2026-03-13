import 'dart:async';

import '../../models/portfolio.dart';
import '../cache_store.dart';
import '../remote/endpoints/portfolio_api.dart';

/// Callback invoked when a background refresh has updated the cache.
typedef OnCacheUpdated = void Function();

class PortfolioRepository {
  final PortfolioApi? _api;
  final CacheStore _cache;
  OnCacheUpdated? onCacheUpdated;

  PortfolioRepository(this._api, this._cache);

  // Cache keys
  static const _summaryKey = 'portfolio:summary';
  static String _historyKey(int days) => 'portfolio:history:$days';
  static String _stockKey(String code, int days) => 'portfolio:stock:$code:$days';

  /// Soft refresh threshold — after this, serve cache but refresh in background.
  Duration _refreshThreshold(int days) {
    if (days <= 7) return const Duration(hours: 1);
    if (days <= 30) return const Duration(hours: 4);
    return const Duration(days: 1);
  }

  // --- Portfolio Summary ---

  Future<PortfolioSummary?> getPortfolioSummary() async {
    if (_api == null) return null;

    final cached = _cache.get<PortfolioSummary>(
      _summaryKey,
      (json) => PortfolioSummary.fromCache(json as Map<String, dynamic>),
    );
    final age = _cache.age(_summaryKey);

    if (cached != null && age != null) {
      if (age > const Duration(minutes: 2)) {
        _refreshSummaryInBackground();
      }
      return cached;
    }
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
      await _cache.put(_summaryKey, summary.toJson());
      return summary;
    } catch (_) {
      // fallback to stale cache
      return _cache.get<PortfolioSummary>(
        _summaryKey,
        (json) => PortfolioSummary.fromCache(json as Map<String, dynamic>),
      );
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
    final key = _historyKey(days);

    final cached = _cache.get<List<PortfolioHistorySnapshot>>(
      key,
      (json) => (json as List)
          .map((r) => PortfolioHistorySnapshot.fromCache(r as Map<String, dynamic>))
          .toList(),
    );
    final age = _cache.age(key);

    if (cached != null && age != null) {
      if (age > _refreshThreshold(days)) {
        _refreshPortfolioHistoryInBackground(days);
      }
      return cached;
    }
    return _fetchPortfolioHistory(days);
  }

  Future<List<PortfolioHistorySnapshot>> _fetchPortfolioHistory(int days) async {
    final key = _historyKey(days);
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
      await _cache.put(key, snapshots.map((s) => s.toJson()).toList());
      return snapshots;
    } catch (_) {
      return _cache.get<List<PortfolioHistorySnapshot>>(
            key,
            (json) => (json as List)
                .map((r) => PortfolioHistorySnapshot.fromCache(r as Map<String, dynamic>))
                .toList(),
          ) ??
          [];
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
    final key = _stockKey(code, days);

    final cached = _cache.get<List<StockHistoryPoint>>(
      key,
      (json) => (json as List)
          .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
    final age = _cache.age(key);

    if (cached != null && age != null) {
      if (age > _refreshThreshold(days)) {
        _refreshStockHistoryInBackground(key, code, days);
      }
      return cached;
    }
    return _fetchStockHistory(key, code, days);
  }

  Future<List<StockHistoryPoint>> _fetchStockHistory(
      String key, String code, int days) async {
    try {
      final json = await _api!.getStockHistory(code, days: days);
      final history = (json['history'] as List? ?? [])
          .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
          .toList();
      await _cache.put(key, history.map((h) => h.toJson()).toList());
      return history;
    } catch (_) {
      return _cache.get<List<StockHistoryPoint>>(
            key,
            (json) => (json as List)
                .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
                .toList(),
          ) ??
          [];
    }
  }

  void _refreshStockHistoryInBackground(
      String key, String code, int days) {
    unawaited(_fetchStockHistory(key, code, days).then((s) {
      if (s.isNotEmpty) onCacheUpdated?.call();
    }));
  }

  // --- Cache management ---

  Future<void> invalidateCache() async {
    await _cache.removeByPrefix('portfolio:');
  }
}
