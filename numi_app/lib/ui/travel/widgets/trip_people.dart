import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../providers/providers.dart';
import 'travel_surfaces.dart';

void showTripPeople(BuildContext context, Trip trip) {
  showTravelSheet(context,
      title: 'Travellers',
      builder: (sheetContext) => Consumer(
            builder: (context, ref, _) {
              final plan = ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                  TripPlan();
              Future<void> edit(PlanItem? person) async {
                var name = person?.title ?? '';
                bool archived = person?.cancelled ?? false;
                final result = await showDialog<PlanItem>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setState) => AlertDialog(
                            title: Text(person == null
                                ? 'Add traveller'
                                : 'Edit traveller'),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                      initialValue: name,
                                      onChanged: (v) => name = v,
                                      autofocus: true,
                                      maxLength: 100,
                                      decoration: const InputDecoration(
                                          labelText: 'Name')),
                                  if (person != null)
                                    SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Archived'),
                                        subtitle: const Text(
                                            'Keeps their existing arrangements'),
                                        value: archived,
                                        onChanged: (v) =>
                                            setState(() => archived = v)),
                                ]),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () {
                                    if (name.trim().isEmpty) return;
                                    Navigator.pop(
                                        ctx,
                                        (person ?? PlanItem.create('person'))
                                            .copy({
                                          'title': name.trim(),
                                          'status':
                                              archived ? 'cancelled' : 'planned'
                                        }));
                                  },
                                  child: const Text('Save'))
                            ],
                          ),
                        ));
                if (result != null) {
                  try {
                    await ref
                        .read(tripPlanRepositoryProvider)
                        .save(trip.id, result);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save: $e')));
                    }
                  }
                }
              }

              return Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Arrangements include everyone unless you select specific people.')),
                ...plan.people.map((p) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(p.title),
                    subtitle: p.cancelled ? const Text('Archived') : null,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => edit(p))),
                TextButton.icon(
                    onPressed: () => edit(null),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add traveller')),
              ]);
            },
          ));
}
