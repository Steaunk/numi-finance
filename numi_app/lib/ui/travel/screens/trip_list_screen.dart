import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/providers.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/sync_status_indicator.dart';
import '../widgets/travel_surfaces.dart';
import 'add_trip_screen.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});
  void add(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => const AddTripScreen());
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);
    final currency = ref.watch(displayCurrencyProvider);
    return Scaffold(
      backgroundColor: travelBackground(context),
      appBar: AppBar(
          title: const Text('Travel'),
          backgroundColor: travelBackground(context),
          surfaceTintColor: Colors.transparent,
          actions: const [CurrencySelector(), SyncStatusIndicator()]),
      body: trips.when(
          data: (records) {
            final upcoming = records
                .where((t) =>
                    tripPhase(t.startDate, t.endDate, DateTime.now()) !=
                    'Completed')
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));
            final past = records
                .where((t) =>
                    tripPhase(t.startDate, t.endDate, DateTime.now()) ==
                    'Completed')
                .toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate));
            Widget card(Trip trip) => Consumer(builder: (context, ref, _) {
                  final plan =
                      ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                          TripPlan();
                  final tasks = plan.ofKind('task');
                  final done =
                      tasks.where((i) => i['status'] == 'completed').length;
                  final count =
                      plan.items.where((i) => i.kind != 'task').length;
                  final total = trip.expenses.fold<double>(
                      0, (sum, e) => sum + e.displayAmount(currency));
                  final colors = Theme.of(context).colorScheme;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: travelSurface(context),
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => context.go('/travel/${trip.id}'),
                          child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(
                                              tripPhase(trip.startDate,
                                                  trip.endDate, DateTime.now()),
                                              style: TextStyle(
                                                  color: colors.primary,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w500))),
                                      Icon(Icons.arrow_forward,
                                          size: 19,
                                          color: colors.onSurfaceVariant)
                                    ]),
                                    const SizedBox(height: 12),
                                    Text(trip.destination,
                                        style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -.7)),
                                    const SizedBox(height: 7),
                                    Text(
                                        '${DateFormat('d MMM').format(trip.startDate)} – ${DateFormat('d MMM yyyy').format(trip.endDate)}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: colors.onSurfaceVariant)),
                                    const SizedBox(height: 22),
                                    Wrap(spacing: 16, runSpacing: 8, children: [
                                      Text(
                                          count == 0
                                              ? 'Your next story starts here'
                                              : '$count saved plans',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant)),
                                      if (trip.expenses.isNotEmpty)
                                        Text(
                                            CurrencyUtils.format(
                                                total, currency),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    colors.onSurfaceVariant)),
                                    ]),
                                    if (tasks.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      LinearProgressIndicator(
                                          value: done / tasks.length,
                                          minHeight: 3,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          backgroundColor: colors.primary
                                              .withValues(alpha: .08)),
                                      const SizedBox(height: 8),
                                      Text(
                                          '$done of ${tasks.length} things ready',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant)),
                                    ],
                                  ])),
                        ),
                      ));
                });
            return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: RefreshIndicator(
                        onRefresh: () =>
                            ref.read(syncStateProvider.notifier).syncNow(),
                        child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                            children: [
                              Text(
                                  upcoming.isEmpty
                                      ? 'Where to next?'
                                      : 'A little further from everyday.',
                                  style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                      letterSpacing: -1)),
                              const SizedBox(height: 12),
                              Text(
                                  'A place for your plans, discoveries and travel memories.',
                                  style: TextStyle(
                                      height: 1.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 28),
                              ...upcoming.map(card),
                              if (records.isEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 36),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.explore_outlined,
                                              size: 36),
                                          const SizedBox(height: 20),
                                          const Text(
                                              'Your first trip is waiting.',
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                              onPressed: () => add(context),
                                              icon: const Icon(Icons.add),
                                              label: const Text('Plan a trip')),
                                        ])),
                              if (past.isNotEmpty)
                                Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(
                                            'Past trips · ${past.length}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500)),
                                        childrenPadding:
                                            const EdgeInsets.only(top: 12),
                                        children: past.map(card).toList())),
                            ]))));
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load trips: $e'))),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => add(context),
          icon: const Icon(Icons.add),
          label: const Text('New trip')),
    );
  }
}
