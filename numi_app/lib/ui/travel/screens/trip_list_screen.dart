import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/providers.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/currency_selector.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/sync_status_indicator.dart';
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
      appBar: AppBar(title: const Text('Travel'), actions: [
        IconButton(
            tooltip: 'Import share link',
            icon: const Icon(Icons.add_link),
            onPressed: () => context.push('/travel/import')),
        const CurrencySelector(),
        const SyncStatusIndicator()
      ]),
      body: trips.when(
          data: (records) {
            if (records.isEmpty) {
              return const EmptyState(
                  icon: Icons.flight_outlined, message: 'No trips yet');
            }
            final now = DateTime.now();
            final upcoming = records
                .where((t) =>
                    tripPhase(t.startDate, t.endDate, now) != 'Completed')
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));
            final past = records
                .where((t) =>
                    tripPhase(t.startDate, t.endDate, now) == 'Completed')
                .toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate));
            Widget card(Trip trip) => Consumer(builder: (context, ref, _) {
                  final plan =
                      ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                          TripPlan();
                  final tasks = plan.ofKind('task');
                  final done =
                      tasks.where((i) => i['status'] == 'completed').length;
                  final count = plan.items
                      .where((i) => i.kind != 'task' && i.kind != 'destination')
                      .length;
                  final total = trip.expenses.fold<double>(
                      0, (sum, e) => sum + e.displayAmount(currency));
                  final theme = Theme.of(context);
                  final secondary = theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
                  return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.go('/travel/${trip.id}'),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(Icons.flight_outlined,
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                          size: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(trip.destination,
                                            style: theme.textTheme.titleSmall),
                                        if (plan.destinations.isNotEmpty)
                                          Text(
                                              plan.destinations
                                                  .map((d) => d.title)
                                                  .join(' → '),
                                              style: secondary),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${DateFormat('d MMM').format(trip.startDate)} – ${DateFormat('d MMM yyyy').format(trip.endDate)}',
                                            style: secondary),
                                        const SizedBox(height: 8),
                                        Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                  tripPhase(trip.startDate,
                                                      trip.endDate, now),
                                                  style: secondary?.copyWith(
                                                      color: theme.colorScheme
                                                          .primary)),
                                              Text('$count planned items',
                                                  style: secondary),
                                              if (trip.expenses.isNotEmpty)
                                                Text(
                                                    CurrencyUtils.format(
                                                        total, currency),
                                                    style: secondary),
                                            ]),
                                        if (tasks.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          LinearProgressIndicator(
                                              value: done / tasks.length,
                                              minHeight: 4,
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          const SizedBox(height: 4),
                                          Text(
                                              '$done/${tasks.length} preparation complete',
                                              style: secondary),
                                        ],
                                      ])),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right,
                                      size: 20,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ])),
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                            children: [
                              ...upcoming.map(card),
                              if (past.isNotEmpty)
                                Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(
                                            'Past trips · ${past.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                        childrenPadding:
                                            const EdgeInsets.only(top: 8),
                                        children: past.map(card).toList())),
                            ]))));
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load trips: $e'))),
      floatingActionButton: FloatingActionButton(
          tooltip: 'New trip',
          onPressed: () => add(context),
          child: const Icon(Icons.add)),
    );
  }
}
