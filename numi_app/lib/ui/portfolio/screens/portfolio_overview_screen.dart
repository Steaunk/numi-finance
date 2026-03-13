import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/portfolio.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/empty_state.dart';

class PortfolioOverviewScreen extends ConsumerWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: const [CurrencySelector()],
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
                const SliverToBoxAdapter(
                  child: _PortfolioHistoryChart(),
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

class _PortfolioSummaryCard extends ConsumerWidget {
  final PortfolioSummary summary;
  const _PortfolioSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(cachedRatesProvider);

    final displayTotal = ratesAsync.when(
      data: (rates) =>
          CurrencyUtils.convert(summary.totalUsd, 'USD', displayCurrency, rates),
      loading: () => summary.totalUsd,
      error: (_, __) => summary.totalUsd,
    );
    final currencyLabel = ratesAsync.hasValue ? displayCurrency : 'USD';

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
              CurrencyUtils.format(displayTotal, currencyLabel),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (summary.totalPnl != 0) ...[
              const SizedBox(height: 2),
              Text(
                '${summary.totalPnl >= 0 ? '+' : ''}${CurrencyUtils.format(
                  ratesAsync.when(
                    data: (rates) => CurrencyUtils.convert(summary.totalPnl, 'USD', displayCurrency, rates),
                    loading: () => summary.totalPnl,
                    error: (_, __) => summary.totalPnl,
                  ),
                  currencyLabel,
                )}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: summary.totalPnl >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 2),
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
      RegExp(r'\bether\b').hasMatch(name) || name.contains('crypto') ||
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
  if (RegExp(r'\bgold\b').hasMatch(name) || RegExp(r'\bsilver\b').hasMatch(name) ||
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

class _PortfolioHistoryChart extends ConsumerStatefulWidget {
  const _PortfolioHistoryChart();

  @override
  ConsumerState<_PortfolioHistoryChart> createState() =>
      _PortfolioHistoryChartState();
}

class _PortfolioHistoryChartState
    extends ConsumerState<_PortfolioHistoryChart> {
  int _selectedDays = 30;
  bool _showPnl = false;
  static const _dayOptions = [7, 30, 90, 180, 365];

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(portfolioHistoryProvider(_selectedDays));
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(cachedRatesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showPnl ? 'Total P&L' : 'Portfolio Value',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Value')),
                      ButtonSegment(value: true, label: Text('P&L')),
                    ],
                    selected: {_showPnl},
                    onSelectionChanged: (v) =>
                        setState(() => _showPnl = v.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _dayOptions.map((d) {
                  final label = d < 365 ? '${d}d' : '1y';
                  final selected = d == _selectedDays;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedDays = d),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: historyAsync.when(
                  data: (history) {
                    if (history.isEmpty) {
                      return const Center(child: Text('No history data'));
                    }
                    return ratesAsync.when(
                      data: (rates) => _buildChart(
                          context, history, displayCurrency, rates),
                      loading: () =>
                          _buildChart(context, history, 'USD', {}),
                      error: (_, __) =>
                          _buildChart(context, history, 'USD', {}),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
      BuildContext context,
      List<PortfolioHistorySnapshot> history,
      String displayCurrency,
      Map<String, double> rates) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final val = _showPnl ? history[i].pnl : history[i].totalUsd;
      final displayVal =
          CurrencyUtils.convert(val, 'USD', displayCurrency, rates);
      spots.add(FlSpot(i.toDouble(), displayVal));
    }
    if (spots.isEmpty) return const Center(child: Text('No data'));

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;
    final chartMinY = _showPnl ? minY - padding : (minY - padding).clamp(0.0, double.infinity);

    final lineColor = _showPnl
        ? (spots.last.y >= 0 ? Colors.green : Colors.red)
        : Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval:
                  (history.length / 4).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('M/d').format(history[idx].timestamp),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 10,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: chartMinY,
        maxY: maxY + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final date = idx < history.length
                    ? DateFormat('yyyy-MM-dd')
                        .format(history[idx].timestamp)
                    : '';
                final prefix = _showPnl && spot.y >= 0 ? '+' : '';
                return LineTooltipItem(
                  '$date\n$prefix${CurrencyUtils.format(spot.y, displayCurrency)}',
                  Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingListTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = totalUsd > 0 ? (holding.usdMarketVal / totalUsd * 100) : 0.0;
    final synthetic = _isSynthetic(holding.code);
    final assetType = _classifyHolding(holding);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final ratesAsync = ref.watch(cachedRatesProvider);

    final displayVal = ratesAsync.when(
      data: (rates) => CurrencyUtils.convert(
          holding.usdMarketVal, 'USD', displayCurrency, rates),
      loading: () => holding.usdMarketVal,
      error: (_, __) => holding.usdMarketVal,
    );
    final currencyLabel = ratesAsync.hasValue ? displayCurrency : 'USD';

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
                    CurrencyUtils.format(displayVal, currencyLabel),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (holding.pnl != 0)
                    Text(
                      '${holding.pnl >= 0 ? '+' : ''}${CurrencyUtils.format(
                        ratesAsync.when(
                          data: (rates) => CurrencyUtils.convert(holding.pnl, 'USD', displayCurrency, rates),
                          loading: () => holding.pnl,
                          error: (_, __) => holding.pnl,
                        ),
                        currencyLabel,
                      )}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: holding.pnl >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                    )
                  else
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
