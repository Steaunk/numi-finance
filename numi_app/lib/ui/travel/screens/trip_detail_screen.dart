import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/amount_display.dart';
import '../../common/widgets/dialogs.dart';
import 'add_travel_expense_screen.dart';

class TripDetailScreen extends ConsumerWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return tripAsync.when(
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trip')),
            body: const Center(child: Text('Trip not found')),
          );
        }
        // Category breakdown
        final categoryTotals = <String, double>{};
        for (final e in trip.expenses) {
          final amount = e.displayAmount(displayCurrency);
          categoryTotals.update(e.category, (v) => v + amount,
              ifAbsent: () => amount);
        }
        final total = categoryTotals.values.fold<double>(0, (a, b) => a + b);

        return Scaffold(
          appBar: AppBar(
            title: Text(trip.destination),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDeleteConfirmDialog(
                    context,
                    title: 'Delete Trip',
                    content:
                        'Delete "${trip.destination}" and all its expenses?',
                  );
                  if (confirm && context.mounted) {
                    await ref
                        .read(travelRepositoryProvider)
                        .deleteTrip(tripId);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Trip info card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppDateUtils.displayDate(trip.startDate)} - ${AppDateUtils.displayDate(trip.endDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (trip.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(trip.notes,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total',
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            CurrencyUtils.format(total, displayCurrency),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Category chips
              if (categoryTotals.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: categoryTotals.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            '${e.key}: ${CurrencyUtils.format(e.value, displayCurrency)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
              // Expenses list
              Expanded(
                child: trip.expenses.isEmpty
                    ? Center(
                        child: Text('No expenses yet',
                            style: Theme.of(context).textTheme.bodyLarge),
                      )
                    : ListView.builder(
                        itemCount: trip.expenses.length,
                        itemBuilder: (context, index) {
                          final expense = trip.expenses[index];
                          return Slidable(
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) async {
                                    final confirm =
                                        await showDeleteConfirmDialog(
                                      context,
                                      title: 'Delete Expense',
                                      content:
                                          'Delete "${expense.name}"?',
                                    );
                                    if (confirm) {
                                      await ref
                                          .read(travelRepositoryProvider)
                                          .deleteTravelExpense(
                                              expense.id, tripId);
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
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => AddTravelExpenseScreen(
                                  tripId: tripId,
                                  tripStartDate: trip.startDate,
                                  tripEndDate: trip.endDate,
                                  expense: expense,
                                ),
                              ),
                              title: Text(expense.name),
                              subtitle: Text(
                                '${AppDateUtils.displayDate(expense.date)} | ${expense.category}',
                              ),
                              trailing: AmountDisplay(
                                amount:
                                    expense.displayAmount(displayCurrency),
                                currency: displayCurrency,
                                originalAmount: expense.amount,
                                originalCurrency: expense.currency,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => AddTravelExpenseScreen(
                tripId: tripId,
                tripStartDate: trip.startDate,
                tripEndDate: trip.endDate,
              ),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
