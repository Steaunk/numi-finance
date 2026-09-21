import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/amount_display.dart';
import '../../common/widgets/dialogs.dart';
import 'add_travel_expense_screen.dart';

/// Existing expense workflow embedded beneath the trip planner navigation.
class TripExpensesScreen extends ConsumerWidget {
  final int tripId;
  const TripExpensesScreen({super.key, required this.tripId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    return ref.watch(tripDetailProvider(tripId)).when(
        data: (trip) {
          if (trip == null) return const Center(child: Text('Trip not found'));
          final totals = <String, double>{};
          for (final e in trip.expenses) {
            totals.update(e.category, (v) => v + e.displayAmount(currency),
                ifAbsent: () => e.displayAmount(currency));
          }
          final total = totals.values.fold<double>(0, (a, b) => a + b);
          return Scaffold(
            body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          Card(
                              child: ListTile(
                                  title: const Text('Recorded expenses'),
                                  trailing: Text(
                                      CurrencyUtils.format(total, currency),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium))),
                          Wrap(
                              spacing: 8,
                              children: totals.entries
                                  .map((e) => Chip(
                                      label: Text(
                                          '${e.key}: ${CurrencyUtils.format(e.value, currency)}')))
                                  .toList()),
                          if (trip.expenses.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Text('No expenses yet'))),
                          ...trip.expenses.map((expense) => Card(
                                  child: ListTile(
                                title: Text(expense.name),
                                subtitle: Text(
                                    '${AppDateUtils.displayDate(expense.date)} · ${expense.category}'),
                                onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => AddTravelExpenseScreen(
                                        tripId: tripId,
                                        tripStartDate: trip.startDate,
                                        tripEndDate: trip.endDate,
                                        expense: expense)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AmountDisplay(
                                          amount:
                                              expense.displayAmount(currency),
                                          currency: currency,
                                          originalAmount: expense.amount,
                                          originalCurrency: expense.currency),
                                      IconButton(
                                          tooltip: 'Delete expense',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            final yes =
                                                await showDeleteConfirmDialog(
                                                    context,
                                                    title: 'Delete expense',
                                                    content:
                                                        'Delete "${expense.name}"?');
                                            if (yes) {
                                              await ref
                                                  .read(
                                                      travelRepositoryProvider)
                                                  .deleteTravelExpense(
                                                      expense.id, tripId);
                                            }
                                          })
                                    ]),
                              ))),
                        ]))),
            floatingActionButton: FloatingActionButton(
                tooltip: 'Add expense',
                onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => AddTravelExpenseScreen(
                        tripId: tripId,
                        tripStartDate: trip.startDate,
                        tripEndDate: trip.endDate)),
                child: const Icon(Icons.add)),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load expenses: $e')));
  }
}
