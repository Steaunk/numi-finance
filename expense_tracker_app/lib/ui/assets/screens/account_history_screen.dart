import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../../config/theme.dart';

class AccountHistoryScreen extends ConsumerWidget {
  final int accountId;
  const AccountHistoryScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(accountHistoryProvider(accountId));
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account History')),
      body: historyAsync.when(
        data: (snapshots) {
          if (snapshots.isEmpty) {
            return const Center(child: Text('No history yet'));
          }
          // Reverse for chronological order in chart
          final chronological = snapshots.reversed.toList();

          return Column(
            children: [
              // Line chart
              SizedBox(
                height: 250,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: (chronological.length / 5)
                                .ceilToDouble()
                                .clamp(1, double.infinity),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 ||
                                  idx >= chronological.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  AppDateUtils.formatDate(
                                      chronological[idx].snapshotDate)
                                      .substring(5),
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
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: chronological
                              .asMap()
                              .entries
                              .map((e) => FlSpot(
                                    e.key.toDouble(),
                                    e.value.balance,
                                  ))
                              .toList(),
                          isCurved: true,
                          color: AppTheme.chartColors[1],
                          barWidth: 2,
                          dotData: FlDotData(
                            show: chronological.length <= 20,
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.chartColors[1]
                                .withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              // Snapshot list
              Expanded(
                child: ListView.builder(
                  itemCount: snapshots.length,
                  itemBuilder: (context, index) {
                    final snap = snapshots[index];
                    final displayAmount =
                        CurrencyUtils.getDisplayAmount(
                      displayCurrency: displayCurrency,
                      amountUsd: snap.amountUsd,
                      amountCny: snap.amountCny,
                      amountHkd: snap.amountHkd,
                      amountSgd: snap.amountSgd,
                    );
                    return ListTile(
                      title: Text(
                        AppDateUtils.displayDate(snap.snapshotDate),
                      ),
                      subtitle: Text(
                        'Balance: ${snap.balance.toStringAsFixed(2)}',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyUtils.format(
                              displayAmount, displayCurrency)),
                          if (snap.change != 0)
                            Text(
                              '${snap.change > 0 ? '+' : ''}${snap.change.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: snap.change > 0
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
