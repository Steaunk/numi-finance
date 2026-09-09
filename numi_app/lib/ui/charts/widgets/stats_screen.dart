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
  final Set<String> _hiddenCategories = {};

  void _toggleCategory(String category) {
    setState(() {
      if (!_hiddenCategories.remove(category)) {
        _hiddenCategories.add(category);
      }
    });
  }

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
                data: (stats) =>
                    _buildBarChart(context, stats, displayCurrency),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 24),
            // Category pie chart
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedMonth != null
                        ? 'Categories ($_selectedMonth)'
                        : 'Categories (All)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_hiddenCategories.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_hiddenCategories.clear),
                    child: const Text('Show all'),
                  ),
              ],
            ),
            Text('Tap a category to hide or show it.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: statsAsync.when(
                data: (stats) =>
                    _buildPieChart(context, stats, displayCurrency),
                loading: () => const Center(child: CircularProgressIndicator()),
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
                loading: () => const Center(child: CircularProgressIndicator()),
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
    final categoryList = allCategories.toList()..sort();
    final categoryColorMap = {
      for (int i = 0; i < categoryList.length; i++)
        categoryList[i]:
            AppTheme.chartColors[i % AppTheme.chartColors.length],
    };

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
                categoryColorMap[categoryList[i]]!,
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
          categoryTotals.update(entry.key, (v) => v + entry.value,
              ifAbsent: () => entry.value);
        }
      }
    }
    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No data'));
    }
    // Build stable color map from all stats categories
    final allCats = <String>{};
    for (final m in stats.values) {
      allCats.addAll(m.keys);
    }
    final sortedCats = allCats.toList()..sort();
    final pieColorMap = {
      for (int i = 0; i < sortedCats.length; i++)
        sortedCats[i]: AppTheme.chartColors[i % AppTheme.chartColors.length],
    };

    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visibleEntries = entries
        .where((entry) =>
            !_hiddenCategories.contains(entry.key) && entry.value > 0)
        .toList();
    final total =
        visibleEntries.fold<double>(0, (sum, entry) => sum + entry.value);

    return Row(
      children: [
        Expanded(
          child: visibleEntries.isEmpty
              ? Center(
                  child: Text(
                    entries.every(
                            (entry) => _hiddenCategories.contains(entry.key))
                        ? 'All categories hidden'
                        : 'No expenses in visible categories',
                    textAlign: TextAlign.center,
                  ),
                )
              : PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final index =
                            response?.touchedSection?.touchedSectionIndex;
                        if (index != null &&
                            index >= 0 &&
                            index < visibleEntries.length) {
                          _toggleCategory(visibleEntries[index].key);
                        }
                      },
                    ),
                    sections: visibleEntries.map((entry) {
                      final percentage = (entry.value / total * 100);
                      return PieChartSectionData(
                        value: entry.value,
                        color:
                            pieColorMap[entry.key] ?? AppTheme.chartColors[0],
                        radius: 50,
                        title: percentage >= 5
                            ? '${percentage.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
        ),
        // Legend
        SizedBox(
          width: 140,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.map((entry) {
                final visible = !_hiddenCategories.contains(entry.key);
                return Semantics(
                  button: true,
                  toggled: visible,
                  label: '${entry.key}, ${visible ? 'shown' : 'hidden'}',
                  child: InkWell(
                    onTap: () => _toggleCategory(entry.key),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: visible
                                  ? pieColorMap[entry.key]
                                  : Theme.of(context).disabledColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 11,
                                color: visible
                                    ? null
                                    : Theme.of(context).disabledColor,
                                decoration:
                                    visible ? null : TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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

    double xOf(String dateStr) {
      final p = dateStr.split('-');
      return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]))
              .millisecondsSinceEpoch /
          Duration.millisecondsPerDay;
    }

    String labelOf(double x) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (x * Duration.millisecondsPerDay).round(),
          isUtc: true);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    String fullDateOf(double x) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
          (x * Duration.millisecondsPerDay).round(),
          isUtc: true);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final spots = trend
        .map((e) => FlSpot(
              xOf(e['date'] as String),
              (e['total'] as num).toDouble(),
            ))
        .toList();

    final minX = spots.first.x;
    final maxX = spots.last.x;
    final rangeDays = (maxX - minX).clamp(1.0, double.infinity);
    final interval = (rangeDays / 5).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value < minX - 0.5 || value > maxX + 0.5) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labelOf(value),
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
            spots: spots,
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
              return LineTooltipItem(
                '${fullDateOf(spot.x)}\n${CurrencyUtils.format(spot.y, currency)}',
                const TextStyle(fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
