import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../models/portfolio.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/empty_state.dart';

class PortfolioOverviewScreen extends ConsumerWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
      ),
      body: summaryAsync.when(
        data: (summary) {
          if (summary == null || summary.holdings.isEmpty) {
            return const EmptyState(
              icon: Icons.show_chart,
              message: 'No portfolio data',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(portfolioRepositoryProvider).invalidateCache();
              ref.invalidate(portfolioSummaryProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PortfolioSummaryCard(summary: summary),
                ),
                SliverToBoxAdapter(
                  child: _AllocationPieChart(summary: summary),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: summary.holdings.length,
                    itemBuilder: (context, index) {
                      final holding = summary.holdings[index];
                      return _HoldingListTile(
                        holding: holding,
                        totalUsd: summary.totalUsd,
                        onTap: () => context.go(
                          '/portfolio/stock/${Uri.encodeComponent(holding.stockName)}',
                          extra: holding,
                        ),
                      );
                    },
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Unable to load portfolio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () {
                    ref.read(portfolioRepositoryProvider).invalidateCache();
                    ref.invalidate(portfolioSummaryProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioSummaryCard extends StatelessWidget {
  final PortfolioSummary summary;
  const _PortfolioSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Portfolio Value',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.format(summary.totalUsd, 'USD'),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.holdings.length} holdings',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AssetType {
  cash(Icons.payments_outlined, Color(0xFF607D8B), 'Cash'),
  fund(Icons.account_balance, Color(0xFF4CAF50), 'Fund'),
  etf(Icons.pie_chart_outline, Color(0xFF2196F3), 'ETF'),
  stock(Icons.show_chart, Color(0xFFFF9800), 'Stock'),
  bond(Icons.shield_outlined, Color(0xFF9C27B0), 'Bond'),
  reit(Icons.apartment, Color(0xFFE91E63), 'REIT'),
  crypto(Icons.currency_bitcoin, Color(0xFFF57C00), 'Crypto'),
  commodity(Icons.diamond_outlined, Color(0xFF00BCD4), 'Commodity');

  final IconData icon;
  final Color color;
  final String label;
  const _AssetType(this.icon, this.color, this.label);
}

_AssetType _classifyHolding(PortfolioHolding h) {
  final code = h.code.toUpperCase();
  if (code == 'CASH') return _AssetType.cash;
  if (code == 'FUND') return _AssetType.fund;
  if (code == 'BOND') return _AssetType.bond;

  final name = h.longName.toLowerCase() + h.stockName.toLowerCase();
  final industry = h.industry.toLowerCase();

  // Crypto ETFs
  if (name.contains('bitcoin') || name.contains('ethereum') ||
      name.contains('ether') || name.contains('crypto') ||
      code.contains('IBIT') || code.contains('ETHA')) {
    return _AssetType.crypto;
  }

  // REIT
  if (name.contains('reit') || industry.contains('reit')) {
    return _AssetType.reit;
  }

  // Bond ETFs
  if (name.contains('bond') || code.contains('BNDW') ||
      code.contains('HYDB')) {
    return _AssetType.bond;
  }

  // Commodity
  if (name.contains('gold') || name.contains('silver') ||
      name.contains('commodity') || industry.contains('commodity')) {
    return _AssetType.commodity;
  }

  // ETF (remaining "Investment Trusts/Mutual Funds")
  if (industry.contains('investment trusts') ||
      industry.contains('mutual fund') ||
      name.contains(' etf')) {
    return _AssetType.etf;
  }

  return _AssetType.stock;
}

class _AllocationPieChart extends StatelessWidget {
  final PortfolioSummary summary;
  const _AllocationPieChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalUsd;

    // Group holdings by asset type
    final Map<_AssetType, double> groups = {};
    for (final h in summary.holdings) {
      final type = _classifyHolding(h);
      groups[type] = (groups[type] ?? 0) + h.usdMarketVal;
    }

    // Sort by value descending
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: sorted.map((e) {
                    final pct = total > 0 ? e.value / total * 100 : 0;
                    return PieChartSectionData(
                      value: e.value,
                      color: e.key.color,
                      radius: 50,
                      title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sorted.map((e) {
                  final pct = total > 0 ? e.value / total * 100 : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(e.key.icon, size: 14, color: e.key.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.key.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingListTile extends StatelessWidget {
  final PortfolioHolding holding;
  final double totalUsd;
  final VoidCallback onTap;

  const _HoldingListTile({
    required this.holding,
    required this.totalUsd,
    required this.onTap,
  });

  static bool _isSynthetic(String code) =>
      code == 'FUND' || code == 'BOND' || code == 'CASH';

  @override
  Widget build(BuildContext context) {
    final pct = totalUsd > 0 ? (holding.usdMarketVal / totalUsd * 100) : 0.0;
    final synthetic = _isSynthetic(holding.code);
    final assetType = _classifyHolding(holding);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: synthetic ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: assetType.color.withAlpha(40),
                child: Icon(
                  assetType.icon,
                  size: 18,
                  color: assetType.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holding.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isSynthetic(holding.code)
                          ? holding.code
                          : '${holding.code}  ${holding.qty.toStringAsFixed(holding.qty == holding.qty.roundToDouble() ? 0 : 2)} shares',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(holding.usdMarketVal, 'USD'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
