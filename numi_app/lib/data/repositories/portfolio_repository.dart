import '../../models/portfolio.dart';
import '../remote/endpoints/portfolio_api.dart';

class PortfolioRepository {
  final PortfolioApi? _api;

  PortfolioSummary? _cachedSummary;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 2);

  PortfolioRepository(this._api);

  bool get _cacheValid =>
      _cachedSummary != null &&
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;

  Future<PortfolioSummary?> getPortfolioSummary() async {
    if (_cacheValid) return _cachedSummary;
    if (_api == null) return null;
    final json = await _api.getHoldings();
    final summary = PortfolioSummary.fromJson(json);
    _cachedSummary = summary;
    _lastFetch = DateTime.now();
    return summary;
  }

  Future<List<StockHistoryPoint>> getStockHistory(
    String stockName, {
    int days = 30,
  }) async {
    if (_api == null) return [];
    final json = await _api.getStockHistory(stockName, days: days);
    final history = (json['history'] as List? ?? [])
        .map((h) => StockHistoryPoint.fromJson(h as Map<String, dynamic>))
        .toList();
    return history;
  }

  Future<List<PortfolioHistorySnapshot>> getPortfolioHistory({
    int days = 30,
  }) async {
    if (_api == null) return [];
    final json = await _api.getHistory(days: days);
    final records = json['history'] as List? ?? [];

    // Aggregate by timestamp: sum usd_market_val for each unique timestamp
    final Map<String, double> totals = {};
    for (final r in records) {
      final ts = r['timestamp'] as String? ?? '';
      final val = (r['usd_market_val'] as num?)?.toDouble() ?? 0;
      totals[ts] = (totals[ts] ?? 0) + val;
    }

    final snapshots = totals.entries.map((e) {
      return PortfolioHistorySnapshot(
        timestamp: DateTime.parse(e.key),
        totalUsd: e.value,
      );
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return snapshots;
  }

  void invalidateCache() {
    _cachedSummary = null;
    _lastFetch = null;
  }
}
