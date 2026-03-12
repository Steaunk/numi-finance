import '../../models/portfolio.dart';
import '../remote/endpoints/portfolio_api.dart';

class PortfolioRepository {
  final PortfolioApi? _api;

  PortfolioSummary? _cachedSummary;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 2);

  // History cache: key = "code:days", value = (data, fetchTime)
  final Map<String, (List<StockHistoryPoint>, DateTime)> _historyCache = {};
  // Portfolio history cache: key = days, value = (data, fetchTime)
  final Map<int, (List<PortfolioHistorySnapshot>, DateTime)> _portfolioHistoryCache = {};

  PortfolioRepository(this._api);

  bool get _cacheValid =>
      _cachedSummary != null &&
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;

  Future<PortfolioSummary?> getPortfolioSummary() async {
    if (_cacheValid) return _cachedSummary;
    if (_api == null) return null;
    final results = await Future.wait([
      _api.getHoldings(),
      _api.getAccount(),
    ]);
    final summary = PortfolioSummary.fromJson(
      results[0],
      accountJson: results[1],
    );
    _cachedSummary = summary;
    _lastFetch = DateTime.now();
    return summary;
  }

  Duration _historyCacheDuration(int days) {
    if (days <= 7) return const Duration(hours: 1);
    if (days <= 30) return const Duration(hours: 4);
    return const Duration(days: 1);
  }

  Future<List<StockHistoryPoint>> getStockHistory(
    String code, {
    int days = 30,
  }) async {
    if (_api == null) return [];
    final cacheKey = '$code:$days';
    final cached = _historyCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.$2) < _historyCacheDuration(days)) {
      return cached.$1;
    }
    final json = await _api.getStockHistory(code, days: days);
    final history = (json['history'] as List? ?? [])
        .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
        .toList();
    _historyCache[cacheKey] = (history, DateTime.now());
    return history;
  }

  Future<List<PortfolioHistorySnapshot>> getPortfolioHistory({
    int days = 30,
  }) async {
    if (_api == null) return [];
    final cached = _portfolioHistoryCache[days];
    if (cached != null && DateTime.now().difference(cached.$2) < _historyCacheDuration(days)) {
      return cached.$1;
    }
    final json = await _api.getHistory(days: days);
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
  }

  void invalidateCache() {
    _cachedSummary = null;
    _lastFetch = null;
    _historyCache.clear();
    _portfolioHistoryCache.clear();
  }
}
