import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/portfolio.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/empty_state.dart';

class PortfolioOverviewScreen extends ConsumerStatefulWidget {
  const PortfolioOverviewScreen({super.key});

  @override
  ConsumerState<PortfolioOverviewScreen> createState() =>
      _PortfolioOverviewScreenState();
}

class _PortfolioOverviewScreenState
    extends ConsumerState<PortfolioOverviewScreen> {
  int _chartDays = 30;
  static const _dayOptions = [7, 30, 90, 180, 365];

  @override
  Widget build(BuildContext context) {
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
              ref.invalidate(portfolioHistoryProvider(_chartDays));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PortfolioSummaryCard(summary: summary),
                ),
                SliverToBoxAdapter(
                  child: _PortfolioChart(
                    days: _chartDays,
                    dayOptions: _dayOptions,
                    onDaysChanged: (d) => setState(() => _chartDays = d),
                  ),
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

class _PortfolioChart extends ConsumerWidget {
  final int days;
  final List<int> dayOptions;
  final ValueChanged<int> onDaysChanged;

  const _PortfolioChart({
    required this.days,
    required this.dayOptions,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(portfolioHistoryProvider(days));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: dayOptions.map((d) {
              final label = d < 365 ? '${d}d' : '1y';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: d == days,
                  onSelected: (_) => onDaysChanged(d),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return const Center(child: Text('No history data'));
                }
                return _buildChart(context, history);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Unable to load chart',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChart(
      BuildContext context, List<PortfolioHistorySnapshot> history) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].totalUsd));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (history.length / 4).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(history[idx].timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
        minY: (minY - padding).clamp(0, double.infinity),
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
                return LineTooltipItem(
                  '$date\n${CurrencyUtils.format(spot.y, 'USD')}',
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.white,
                      ),
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
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withAlpha(30),
            ),
          ),
        ],
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

  static IconData _syntheticIcon(String code) {
    switch (code) {
      case 'FUND':
        return Icons.account_balance;
      case 'BOND':
        return Icons.shield_outlined;
      case 'CASH':
        return Icons.payments_outlined;
      default:
        return Icons.attach_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = totalUsd > 0 ? (holding.usdMarketVal / totalUsd * 100) : 0.0;
    final synthetic = _isSynthetic(holding.code);

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
                backgroundColor: synthetic
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: synthetic
                    ? Icon(
                        _syntheticIcon(holding.code),
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer,
                      )
                    : Text(
                        holding.code.length >= 2
                            ? holding.code.substring(0, 2)
                            : holding.code,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
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
