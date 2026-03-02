import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/sync_status_indicator.dart';
import '../../common/widgets/amount_display.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final expensesAsync = ref.watch(expenseListProvider(selectedMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [
          CurrencySelector(),
          SyncStatusIndicator(),
          _SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          // Month picker
          _MonthPicker(
            selected: selectedMonth,
            onChanged: (month) =>
                ref.read(selectedMonthProvider.notifier).state = month,
          ),
          // Total card
          expensesAsync.when(
            data: (expenses) {
              final total = expenses.fold<double>(
                0,
                (sum, e) => sum + CurrencyUtils.getDisplayAmount(
                  displayCurrency: displayCurrency,
                  amountUsd: e.amountUsd,
                  amountCny: e.amountCny,
                  amountHkd: e.amountHkd,
                  amountSgd: e.amountSgd,
                  originalAmount: e.amount,
                  originalCurrency: e.currency,
                ),
              );
              return _TotalCard(total: total, currency: displayCurrency);
            },
            loading: () => const _TotalCard(total: 0, currency: ''),
            error: (e, _) => const SizedBox.shrink(),
          ),
          // Expense list
          Expanded(
            child: expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No expenses this month',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(syncStateProvider.notifier).syncNow(),
                  child: ListView.builder(
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final displayAmount = CurrencyUtils.getDisplayAmount(
                        displayCurrency: displayCurrency,
                        amountUsd: expense.amountUsd,
                        amountCny: expense.amountCny,
                        amountHkd: expense.amountHkd,
                        amountSgd: expense.amountSgd,
                        originalAmount: expense.amount,
                        originalCurrency: expense.currency,
                      );
                      return Slidable(
                        endActionPane: ActionPane(
                          motion: const BehindMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Expense'),
                                    content: Text(
                                        'Delete "${expense.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(expenseRepositoryProvider)
                                      .deleteExpense(expense.id);
                                }
                              },
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onError,
                              icon: Icons.delete,
                              label: 'Delete',
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            child: Text(
                              expense.category.isNotEmpty
                                  ? expense.category[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(expense.name),
                          subtitle: Text(
                            '${AppDateUtils.displayDate(expense.date)} | ${expense.category}',
                          ),
                          trailing: AmountDisplay(
                            amount: displayAmount,
                            currency: displayCurrency,
                            originalAmount: expense.amount,
                            originalCurrency: expense.currency,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => const AddExpenseScreen(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () => context.push('/settings'),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  const _MonthPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(AppDateUtils.previousMonth(selected)),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selected,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onChanged(picked);
            },
            child: Text(
              AppDateUtils.displayMonth(selected),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(AppDateUtils.nextMonth(selected)),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final String currency;

  const _TotalCard({required this.total, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: Theme.of(context).textTheme.titleSmall),
            Text(
              currency.isNotEmpty
                  ? CurrencyUtils.format(total, currency)
                  : '...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
