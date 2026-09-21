import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../providers/providers.dart';
import '../../common/widgets/dialogs.dart';
import 'plan_item_editor.dart';
import 'travel_surfaces.dart';

Future<void> showTripDestinations(BuildContext context, Trip trip) =>
    showTravelSheet(context,
        title: 'Destinations',
        builder: (_) => Consumer(
              builder: (context, ref, _) {
                final plan = ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                    TripPlan();
                final repo = ref.read(tripPlanRepositoryProvider);
                Future<void> run(Future<void> Function() work) async {
                  try {
                    await work();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Could not save destination: $e')));
                    }
                  }
                }

                Future<void> edit(PlanItem item) async {
                  final result = await editPlanItem(context, trip, plan, item);
                  if (result != null) {
                    await run(() => repo.save(trip.id, result));
                  }
                }

                final destinations = plan.destinations;
                return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    children: [
                      const Text(
                          'Add cities, regions or countries in travel order. Visit dates can overlap on transfer days.'),
                      const SizedBox(height: 16),
                      for (var index = 0;
                          index < destinations.length;
                          index++) ...[
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(destinations[index].title),
                            subtitle: Text(
                                '${travelDate(destinations[index]['date'])} – ${travelDate(destinations[index]['endDate'])}'),
                            onTap: () => edit(destinations[index]),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              for (final delta in [-1, 1])
                                IconButton(
                                    tooltip: delta < 0
                                        ? 'Move destination up'
                                        : 'Move destination down',
                                    icon: Icon(
                                        delta < 0
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 18),
                                    onPressed: index + delta < 0 ||
                                            index + delta >= destinations.length
                                        ? null
                                        : () => run(() async {
                                              final ids = destinations
                                                  .map((d) => d.id)
                                                  .toList();
                                              final id = ids.removeAt(index);
                                              ids.insert(index + delta, id);
                                              await repo.reorder(trip.id, ids);
                                            })),
                              IconButton(
                                  tooltip: 'Delete destination',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final yes = await showDeleteConfirmDialog(
                                        context,
                                        title: 'Delete destination',
                                        content:
                                            'Remove "${destinations[index].title}"? Places, bookings, activities and payments will be kept and unassigned.');
                                    if (yes) {
                                      await run(() => repo.remove(
                                          trip.id, destinations[index].id));
                                    }
                                  }),
                            ])),
                        const Divider(),
                      ],
                      FilledButton.icon(
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add destination'),
                          onPressed: () => edit(PlanItem.create('destination')
                                  .copy({
                                'date': planDate(trip.startDate),
                                'endDate': planDate(trip.endDate)
                              }))),
                    ]);
              },
            ));
