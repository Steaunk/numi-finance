import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/amount_display.dart';
import '../../common/widgets/dialogs.dart';
import 'add_travel_expense_screen.dart';
import '../../../models/travel_expense.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';

/// Spending shares the trip workspace's destination filter and scroll view.
class TripExpensesScreen extends ConsumerWidget {
  final int tripId;
  final String destination;
  final ValueChanged<String> onDestinationChanged;
  const TripExpensesScreen(
      {super.key,
      required this.tripId,
      this.destination = '',
      required this.onDestinationChanged});

  void revealDestination(String savedDestination) {
    if (destination.isNotEmpty) {
      onDestinationChanged(
          savedDestination.isEmpty ? '__unassigned__' : savedDestination);
    }
  }

  Future<void> editExpense(BuildContext context, WidgetRef ref, Trip trip,
      TravelExpense expense) async {
    {
      final savedDestination = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 680),
          builder: (_) => AddTravelExpenseScreen(
              tripId: tripId,
              tripStartDate: trip.startDate,
              tripEndDate: trip.endDate,
              expense: expense));
      if (context.mounted && savedDestination != null) {
        revealDestination(savedDestination);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final plan = ref.watch(tripPlanProvider(tripId)).valueOrNull ?? TripPlan();
    return ref.watch(tripDetailProvider(tripId)).when(
        data: (trip) {
          if (trip == null) return const Center(child: Text('Trip not found'));
          final selected = destination == '__unassigned__' ? '' : destination;
          final expenses = trip.expenses
              .where((e) =>
                  destination.isEmpty ||
                  plan.expenseDestination(
                        e.planItemIds,
                        destinationId: e.destinationId,
                      ) ==
                      selected)
              .toList();
          final totals = <String, double>{};
          for (final e in expenses) {
            totals.update(e.category, (v) => v + e.displayAmount(currency),
                ifAbsent: () => e.displayAmount(currency));
          }
          final total = totals.values.fold<double>(0, (a, b) => a + b);
          final content = <Widget>[
            Card(
                child: ListTile(
                    title: const Text('Recorded expenses'),
                    trailing: Text(CurrencyUtils.format(total, currency),
                        style: Theme.of(context).textTheme.titleMedium))),
            Wrap(
                spacing: 8,
                children: totals.entries
                    .map((e) => Chip(
                        label: Text(
                            '${e.key}: ${CurrencyUtils.format(e.value, currency)}')))
                    .toList()),
            if (expenses.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No expenses yet'))),
            ...expenses.map((expense) => Card(
                    child: ListTile(
                  title: Text(expense.name),
                  subtitle: Text(
                    '${AppDateUtils.displayDate(expense.date)} · ${expense.category}${expense.planItemIds.isEmpty ? '' : ' · ${expense.planItemIds.length} linked'} · ${plan.expenseDestinationLabel(plan.expenseDestination(expense.planItemIds, destinationId: expense.destinationId))}',
                  ),
                  onTap: () => editExpense(context, ref, trip, expense),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    AmountDisplay(
                        amount: expense.displayAmount(currency),
                        currency: currency,
                        originalAmount: expense.amount,
                        originalCurrency: expense.currency),
                    IconButton(
                        tooltip: 'Delete expense',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final yes = await showDeleteConfirmDialog(context,
                              title: 'Delete expense',
                              content:
                                  'Delete "${expense.name}"? Linked itinerary items will be kept.');
                          if (yes) {
                            await ref
                                .read(travelRepositoryProvider)
                                .deleteTravelExpense(expense.id, tripId);
                          }
                        })
                  ]),
                ))),
          ];
          Future<void> addExpense() async {
            final savedDestination = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                useRootNavigator: true,
                builder: (_) => AddTravelExpenseScreen(
                    tripId: tripId,
                    initialDestination: destination,
                    tripStartDate: trip.startDate,
                    tripEndDate: trip.endDate));
            if (context.mounted && savedDestination != null) {
              revealDestination(savedDestination);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: addExpense,
                icon: const Icon(Icons.add),
                label: const Text('Add expense'),
              ),
              const SizedBox(height: 12),
              ...content,
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load expenses: $e')));
  }
}
