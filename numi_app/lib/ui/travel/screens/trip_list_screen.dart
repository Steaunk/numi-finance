import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../../utils/date_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/sync_status_indicator.dart';
import 'add_trip_screen.dart';
import '../widgets/travel_style.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const TravelTheme(child: _TripListBody());
}

class _TripListBody extends ConsumerWidget {
  const _TripListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripListProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel'),
        actions: const [CurrencySelector(), SyncStatusIndicator()],
      ),
      body: TravelPageWidth(
          child: tripsAsync.when(
        data: (trips) {
          if (trips.isEmpty) {
            return const EmptyState(
              icon: Icons.flight,
              message: 'No trips yet',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(syncStateProvider.notifier).syncNow(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: trips.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('OUT OF THE EVERYDAY',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Text('Where to next?',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -1)),
                          const SizedBox(height: 8),
                          Text('Your places, plans and little adventures.',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                  );
                }
                final trip = trips[index - 1];
                final total = trip.expenses.fold<double>(
                  0,
                  (sum, e) => sum + e.displayAmount(displayCurrency),
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go('/travel/${trip.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TravelKindIcon('activity'),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  trip.destination,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${AppDateUtils.displayDate(trip.startDate)} - ${AppDateUtils.displayDate(trip.endDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          Row(children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('${trip.expenses.length} expenses',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)),
                            Text(CurrencyUtils.format(total, displayCurrency),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => const AddTripScreen(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
    );
  }
}
