import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/amount_display.dart';
import '../../common/widgets/dialogs.dart';
import 'add_travel_expense_screen.dart';
import '../widgets/plan_item_editor.dart';
import '../../../models/travel_expense.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';

/// Existing expense workflow embedded beneath the trip planner navigation.
class TripExpensesScreen extends ConsumerStatefulWidget {
  final int tripId;
  const TripExpensesScreen({super.key, required this.tripId});
  @override
  ConsumerState<TripExpensesScreen> createState() => _TripExpensesScreenState();
}

class _TripExpensesScreenState extends ConsumerState<TripExpensesScreen> {
  int get tripId => widget.tripId;
  String selectedDestination = '__all__';
  Future<void> editExpense(BuildContext context, WidgetRef ref, Trip trip,
      TravelExpense expense) async {
    if (expense.planItemId == null) {
      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 680),
          builder: (_) => AddTravelExpenseScreen(
              tripId: tripId,
              tripStartDate: trip.startDate,
              tripEndDate: trip.endDate,
              expense: expense));
      return;
    }
    try {
      final repo = ref.read(tripPlanRepositoryProvider);
      final booking = await repo.itemFromExpense(tripId, expense.id);
      final plan = await repo.watch(tripId).first;
      if (!context.mounted) return;
      final result = await editPlanItem(context, trip, plan, booking);
      if (result != null) await repo.save(tripId, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open itinerary item: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(displayCurrencyProvider);
    final plan = ref.watch(tripPlanProvider(tripId)).valueOrNull ?? TripPlan();
    return ref.watch(tripDetailProvider(tripId)).when(
        data: (trip) {
          if (trip == null) return const Center(child: Text('Trip not found'));
          final groups = <String, double>{};
          for (final e in trip.expenses) {
            final key = plan.expenseDestination(e.planItemId);
            groups.update(key, (v) => v + e.displayAmount(currency),
                ifAbsent: () => e.displayAmount(currency));
          }
          final selected = selectedDestination == '__all__' ||
                  groups.containsKey(selectedDestination)
              ? selectedDestination
              : '__all__';
          final expenses = trip.expenses
              .where((e) =>
                  selected == '__all__' ||
                  plan.expenseDestination(e.planItemId) == selected)
              .toList();
          final totals = <String, double>{};
          for (final e in expenses) {
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
                          if (plan.destinations.isNotEmpty ||
                              groups.length > 1) ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey('expense-destination-$selected'),
                              initialValue: selected,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Spending by destination'),
                              items: [
                                const DropdownMenuItem(
                                    value: '__all__',
                                    child: Text('All destinations')),
                                ...groups.entries.map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                        '${plan.expenseDestinationLabel(e.key)} · ${CurrencyUtils.format(e.value, currency)}',
                                        overflow: TextOverflow.ellipsis)))
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedDestination = v!),
                            ),
                            const SizedBox(height: 12),
                          ],
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
                          if (expenses.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Text('No expenses yet'))),
                          ...expenses.map((expense) => Card(
                                  child: ListTile(
                                title: Text(expense.name),
                                subtitle: Text(
                                    '${AppDateUtils.displayDate(expense.date)} · ${expense.category}${expense.planItemId == null ? '' : ' · Itinerary'} · ${plan.expenseDestinationLabel(plan.expenseDestination(expense.planItemId))}'),
                                onTap: () =>
                                    editExpense(context, ref, trip, expense),
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
                                            final yes = await showDeleteConfirmDialog(
                                                context,
                                                title: 'Delete expense',
                                                content: expense.planItemId ==
                                                        null
                                                    ? 'Delete "${expense.name}"?'
                                                    : 'Remove the recorded payment for "${expense.name}"? The itinerary item will remain unpaid.');
                                            if (yes) {
                                              if (expense.planItemId != null) {
                                                await ref
                                                    .read(
                                                        tripPlanRepositoryProvider)
                                                    .removePayment(tripId,
                                                        expense.planItemId!);
                                              } else {
                                                await ref
                                                    .read(
                                                        travelRepositoryProvider)
                                                    .deleteTravelExpense(
                                                        expense.id, tripId);
                                              }
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
