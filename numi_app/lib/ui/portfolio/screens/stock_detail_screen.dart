import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../models/portfolio.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String stockName;
  final PortfolioHolding? holding;

  const StockDetailScreen({
    super.key,
    required this.stockName,
    this.holding,
  });

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  int _selectedDays = 30;

  static const _dayOptions = [7, 30, 90, 180, 365];

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final historyAsync = ref.watch(
      stockHistoryProvider(
        (stockName: widget.stockName, days: _selectedDays),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(holding?.displayName ?? widget.stockName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            if (holding != null) _buildHeaderCard(context, holding),
            const SizedBox(height: 16),

            // Time range selector
            Row(
              children: _dayOptions.map((d) {
                final label = d < 365 ? '${d}d' : '1y';
                final selected = d == _selectedDays;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedDays = d),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 250,
              child: historyAsync.when(
                data: (history) {
                  if (history.isEmpty) {
                    return const Center(child: Text('No history data'));
                  }
                  return _buildChart(context, history);
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),

            // Details section
            if (holding != null) ...[
              const SizedBox(height: 24),
              _buildDetailsSection(context, holding),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, PortfolioHolding holding) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(holding.code,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  CurrencyUtils.format(holding.usdMarketVal, 'USD'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  holding.displayName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                if (holding.currency.isNotEmpty)
                  Text(
                    CurrencyUtils.format(holding.marketValue, holding.currency),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<StockHistoryPoint> history) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].usdMarketVal));
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
                final date = history[idx].timestamp;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(date),
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
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.x.toInt();
                final date = idx < history.length
                    ? DateFormat('yyyy-MM-dd').format(history[idx].timestamp)
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
              color:
                  Theme.of(context).colorScheme.primary.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
      BuildContext context, PortfolioHolding holding) {
    final details = <(String, String)>[
      ('Quantity', holding.qty.toStringAsFixed(
          holding.qty == holding.qty.roundToDouble() ? 0 : 4)),
      ('Price', CurrencyUtils.format(holding.nominalPrice, holding.currency)),
      if (holding.currency.isNotEmpty) ('Currency', holding.currency),
      if (holding.positionMarket.isNotEmpty) ('Market', holding.positionMarket),
      if (holding.sector.isNotEmpty) ('Sector', holding.sector),
      if (holding.industry.isNotEmpty) ('Industry', holding.industry),
      if (holding.country.isNotEmpty) ('Country', holding.country),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(d.$1,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              )),
                      Text(d.$2,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
