import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/account.dart';
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
    final accounts = ref.watch(accountListProvider).valueOrNull ?? [];
    final account =
        accounts.where((a) => a.id == accountId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(account?.name ?? 'Account History')),
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
      floatingActionButton: account != null
          ? FloatingActionButton(
              onPressed: () =>
                  _showModifyBalanceDialog(context, ref, account),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  void _showModifyBalanceDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final controller =
        TextEditingController(text: account.balance.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modify Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${CurrencyUtils.format(account.balance, account.currency)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Balance',
                suffixText: account.currency,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newBalance = double.tryParse(controller.text);
              if (newBalance == null) return;
              Navigator.pop(ctx);
              await ref.read(assetRepositoryProvider).updateAccount(
                    account.id,
                    name: account.name,
                    currency: account.currency,
                    balance: newBalance,
                    includeInTotal: account.includeInTotal,
                    notes: account.notes,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Balance updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
