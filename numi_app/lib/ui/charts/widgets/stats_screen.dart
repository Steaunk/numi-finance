import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../config/theme.dart';
import '../../common/widgets/currency_selector.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final statsAsync = ref.watch(monthlyStatsProvider(null));
    final trendAsync = ref.watch(netWorthTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charts'),
        actions: const [CurrencySelector()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly expenses bar chart
            Text('Monthly Expenses',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: statsAsync.when(
                data: (stats) => _buildBarChart(
                    context, stats, displayCurrency),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 24),
            // Category pie chart
            Text(
              _selectedMonth != null
                  ? 'Categories ($_selectedMonth)'
                  : 'Categories (All)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: statsAsync.when(
                data: (stats) => _buildPieChart(
                    context, stats, displayCurrency),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 24),
            // Net worth trend
            Text('Net Worth Trend',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: trendAsync.when(
                data: (trend) =>
                    _buildTrendChart(context, trend, displayCurrency),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    BuildContext context,
    Map<String, Map<String, double>> stats,
    String currency,
  ) {
    if (stats.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final months = stats.keys.toList()..sort();
    // Collect all categories
    final allCategories = <String>{};
    for (final m in stats.values) {
      allCategories.addAll(m.keys);
    }
    final categoryList = allCategories.toList();

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (event.isInterestedForInteractions &&
                response?.spot != null) {
              final idx = response!.spot!.touchedBarGroupIndex;
              if (idx >= 0 && idx < months.length) {
                setState(() => _selectedMonth = months[idx]);
              }
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = months[group.x.toInt()];
              final total = stats[month]!.values.fold<double>(
                  0, (a, b) => a + b);
              return BarTooltipItem(
                '$month\n${CurrencyUtils.format(total, currency)}',
                const TextStyle(fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    months[idx].substring(5), // MM
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
        barGroups: months.asMap().entries.map((entry) {
          final idx = entry.key;
          final month = entry.value;
          final categories = stats[month]!;
          // Build stacked rod
          final rodStackItems = <BarChartRodStackItem>[];
          double cumulative = 0;
          for (int i = 0; i < categoryList.length; i++) {
            final amount = categories[categoryList[i]] ?? 0;
            if (amount > 0) {
              rodStackItems.add(BarChartRodStackItem(
                cumulative,
                cumulative + amount,
                AppTheme.chartColors[i % AppTheme.chartColors.length],
              ));
              cumulative += amount;
            }
          }
          return BarChartGroupData(
            x: idx,
            barRods: [
              BarChartRodData(
                toY: cumulative,
                rodStackItems: rodStackItems,
                width: months.length > 6 ? 12 : 20,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    Map<String, Map<String, double>> stats,
    String currency,
  ) {
    // Aggregate by category for selected month or all
    final Map<String, double> categoryTotals = {};
    if (_selectedMonth != null && stats.containsKey(_selectedMonth)) {
      categoryTotals.addAll(stats[_selectedMonth]!);
    } else {
      for (final m in stats.values) {
        for (final entry in m.entries) {
          categoryTotals.update(
              entry.key, (v) => v + entry.value,
              ifAbsent: () => entry.value);
        }
      }
    }
    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No data'));
    }
    final total = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              sections: entries.asMap().entries.map((e) {
                final idx = e.key;
                final entry = e.value;
                final percentage = (entry.value / total * 100);
                return PieChartSectionData(
                  value: entry.value,
                  color: AppTheme
                      .chartColors[idx % AppTheme.chartColors.length],
                  radius: 50,
                  title: percentage >= 5
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        // Legend
        SizedBox(
          width: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.chartColors[
                            idx % AppTheme.chartColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<Map<String, dynamic>> trend,
    String currency,
  ) {
    if (trend.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval:
                  (trend.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    (trend[idx]['date'] as String).substring(5),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: trend
                .asMap()
                .entries
                .map((e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['total'] as num).toDouble(),
                    ))
                .toList(),
            isCurved: true,
            color: AppTheme.chartColors[4],
            barWidth: 2,
            dotData: FlDotData(show: trend.length <= 20),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.chartColors[4].withValues(alpha: 0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.x.toInt();
              final date = idx < trend.length
                  ? trend[idx]['date'] as String
                  : '';
              return LineTooltipItem(
                '$date\n${CurrencyUtils.format(spot.y, currency)}',
                const TextStyle(fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
