import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/portfolio.dart';
import 'core.dart';

final portfolioSummaryProvider = FutureProvider<PortfolioSummary?>((ref) {
  ref.watch(portfolioRefreshCounter); // re-fetch on background refresh
  return ref.watch(portfolioRepositoryProvider).getPortfolioSummary();
});

final portfolioHistoryProvider =
    FutureProvider.family<List<PortfolioHistorySnapshot>, int>((ref, days) {
  ref.watch(portfolioRefreshCounter); // re-fetch on background refresh
  return ref.watch(portfolioRepositoryProvider).getPortfolioHistory(days: days);
});

final stockHistoryProvider = FutureProvider.family<List<StockHistoryPoint>,
    ({String code, int days})>((ref, params) {
  return ref
      .watch(portfolioRepositoryProvider)
      .getStockHistory(params.code, days: params.days);
});

/// Pings /portfolio/api/broker-status/ when watched. The backend uses this
/// request to detect an unhealthy IBKR session and auto-restart ibkr_gateway.
/// Returns null on any error so UI watchers never fail on this ping.
final brokerStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(portfolioApiProvider);
  if (api == null) return null;
  try {
    return await api.getBrokerStatus();
  } catch (_) {
    return null;
  }
});

/// Top-N look-through holdings (direct + ETF constituent exposure, aggregated).
final lookThroughProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, limit) async {
  final api = ref.watch(portfolioApiProvider);
  if (api == null) return null;
  return api.getLookThrough(limit: limit);
});
