import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/dialogs.dart';
import '../widgets/plan_item_editor.dart';
import '../widgets/plan_links.dart';
import 'trip_expenses_screen.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});
  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  String? selectedDay;
  String category = 'All';
  String priority = 'All';
  String scheduled = 'All';
  String checklist = 'All';
  bool resolving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(tripPlanRepositoryProvider).sync(widget.tripId));
      }
    });
  }

  Future<void> action(Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  Future<void> edit(Trip trip, TripPlan plan, PlanItem item) async {
    final result = await editPlanItem(context, trip, plan, item);
    if (result != null && mounted) {
      await action(
          () => ref.read(tripPlanRepositoryProvider).save(trip.id, result));
    }
  }

  Future<void> remove(Trip trip, PlanItem item) async {
    final yes = await showDeleteConfirmDialog(context,
        title: 'Delete ${item.kind}',
        content: item.kind == 'place'
            ? 'Remove this place? Linked activities will be kept without the place link.'
            : 'Remove this item from your plan?');
    if (yes && mounted) {
      await action(
          () => ref.read(tripPlanRepositoryProvider).remove(trip.id, item.id));
    }
  }

  Future<void> resolve(bool keepLocal) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(
                    keepLocal ? 'Replace server plan?' : 'Use server plan?'),
                content: Text(keepLocal
                    ? 'This replaces the server plan with the complete plan on this device. Changes made on another device will be replaced.'
                    : 'This replaces the complete plan on this device with the server version. Unsynced local changes will be discarded.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => resolving = true);
    await action(() => ref
        .read(tripPlanRepositoryProvider)
        .resolve(widget.tripId, keepLocal: keepLocal));
    if (mounted) setState(() => resolving = false);
  }

  Widget page(List<Widget> children) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child:
              ListView(padding: const EdgeInsets.all(16), children: children)));
  Widget heading(String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (trailing != null) trailing
      ]));
  Widget empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(child: Text(text, textAlign: TextAlign.center)));
  Widget addButton(String text, VoidCallback onPressed) =>
      FilledButton.tonalIcon(
          onPressed: onPressed, icon: const Icon(Icons.add), label: Text(text));
  Widget filter(String label, String value, List<String> choices,
          ValueChanged<String> update) =>
      SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
              key: ValueKey('$label-$value'),
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: choices
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => update(v!)));
  IconData icon(PlanItem i) => switch (i.kind) {
        'place' => switch (i['category']) {
            'Restaurant' || 'Cafe' => Icons.restaurant,
            'Shopping' => Icons.shopping_bag_outlined,
            _ => Icons.place_outlined
          },
        'booking' => switch (i['category']) {
            'Accommodation' => Icons.hotel_outlined,
            'Flight' => Icons.flight,
            'No accommodation needed' => Icons.nights_stay_outlined,
            _ => Icons.confirmation_number_outlined
          },
        'task' => Icons.checklist,
        _ => Icons.event_outlined,
      };
  Widget selectable(String value) => SelectionArea(child: Text(value));

  Widget card(Trip trip, TripPlan plan, PlanItem item, {Widget? handle}) {
    final place = plan.find(item['placeId']);
    final address = place?['address'] ?? item['address'];
    final links = [...?place?.links, ...item.links];
    final parts = [
      item['category'],
      item['status'],
      if (item['date'].isNotEmpty) item['date'],
      if (item['time'].isNotEmpty) '${item['time']} ${item['timezone']}',
      if (item['endDate'].isNotEmpty)
        'to ${item['endDate']} ${item['endTime']} ${item['endTimezone']}',
      if (item['endDate'].isEmpty && item['endTime'].isNotEmpty)
        'until ${item['endTime']}',
      if (item.kind == 'place') item['priority']
    ];
    return Card(
        child: ExpansionTile(
      key: PageStorageKey('plan-${item.id}'),
      leading: Icon(icon(item)),
      title: Text(plan.itemTitle(item),
          maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: Text(parts.where((s) => s.isNotEmpty).join(' · '),
          maxLines: 4, overflow: TextOverflow.ellipsis),
      trailing: handle,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place != null) Text('Linked place: ${place.title}'),
        if (address.isNotEmpty) selectable(address),
        if (item['endAddress'].isNotEmpty)
          selectable('Arrival: ${item['endAddress']}'),
        if (item['confirmation'].isNotEmpty)
          selectable('Confirmation: ${item['confirmation']}'),
        if (item['contact'].isNotEmpty)
          selectable('Contact: ${item['contact']}'),
        if (item['cancelBy'].isNotEmpty)
          Text('Cancellation deadline: ${item['cancelBy']}'),
        if (item['notes'].isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: selectable(item['notes'])),
        if (place != null && place['notes'].isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Place notes: ${place['notes']}')),
        if (item['time'].isNotEmpty || item['endTime'].isNotEmpty)
          const Text('Times are local to the stated time zone.',
              style: TextStyle(fontSize: 12)),
        PlanLinks(links: links),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TextButton.icon(
              onPressed: () => edit(trip, plan, item),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit')),
          if (address.isNotEmpty || item.kind == 'place')
            TextButton.icon(
                onPressed: () => openPlanLink(
                    context,
                    mapSearchLink(place?.title ?? plan.itemTitle(item), address)
                        .toString()),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Google Maps')),
          if (address.isNotEmpty || item.kind == 'place')
            TextButton.icon(
                onPressed: () => openPlanLink(
                    context,
                    baiduMapSearchLink(place?.title ?? plan.itemTitle(item),
                            address, trip.destination)
                        .toString()),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Baidu Maps')),
          if (item['endAddress'].isNotEmpty)
            TextButton(
                onPressed: () => openPlanLink(
                    context, mapSearchLink('', item['endAddress']).toString()),
                child: const Text('Arrival · Google Maps')),
          if (item['endAddress'].isNotEmpty)
            TextButton(
                onPressed: () => openPlanLink(
                    context,
                    baiduMapSearchLink('', item['endAddress'], trip.destination)
                        .toString()),
                child: const Text('Arrival · Baidu Maps')),
          if (item.kind == 'place')
            TextButton.icon(
                onPressed: () => edit(
                    trip,
                    plan,
                    PlanItem.create('activity').copy({
                      'placeId': item.id,
                      'date': selectedDay ?? planDate(trip.startDate)
                    })),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add to itinerary')),
          if (item['status'] != 'completed')
            TextButton(
                onPressed: () => action(() => ref
                    .read(tripPlanRepositoryProvider)
                    .save(trip.id, item.copy({'status': 'completed'}))),
                child: const Text('Mark completed')),
          TextButton(
              onPressed: () => remove(trip, item), child: const Text('Delete')),
        ]),
      ],
    ));
  }

  Widget overview(Trip trip, TripPlan plan) {
    final days = tripDays(trip.startDate, trip.endDate);
    final today = planDate(DateTime.now());
    final day =
        days.map(planDate).where((d) => d.compareTo(today) >= 0).firstOrNull ??
            planDate(trip.endDate);
    final activities =
        plan.ofKind('activity').where((i) => i['date'] == day).toList();
    final bookings = plan.bookingsOn(day);
    final upcoming = plan
        .ofKind('booking')
        .where((i) => !i.cancelled && i['date'].compareTo(day) > 0)
        .toList()
      ..sort((a, b) => a['date'].compareTo(b['date']));
    final tasks = plan.ofKind('task');
    final outstanding = tasks.where((t) => t['status'] != 'completed').toList();
    final missingNights = days
        .take(days.isEmpty ? 0 : days.length - 1)
        .map(planDate)
        .where((d) => !plan.hasStay(d))
        .toList();
    final deadlines = plan
        .ofKind('booking')
        .where((i) =>
            !i.cancelled &&
            i['cancelBy'].isNotEmpty &&
            i['cancelBy'].compareTo(today) >= 0)
        .toList()
      ..sort((a, b) => a['cancelBy'].compareTo(b['cancelBy']));
    final currency = ref.watch(displayCurrencyProvider);
    final total =
        trip.expenses.fold<double>(0, (v, e) => v + e.displayAmount(currency));
    return page([
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        tripPhase(trip.startDate, trip.endDate, DateTime.now()),
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(
                        '${planDate(trip.startDate)} — ${planDate(trip.endDate)}'),
                    if (trip.notes.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(trip.notes)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      Chip(
                          label: Text('${plan.ofKind('place').length} places')),
                      Chip(
                          label: Text(
                              '${plan.ofKind('activity').length} activities')),
                      Chip(
                          label: Text(
                              '${tasks.length - outstanding.length}/${tasks.length} prepared')),
                      Chip(label: Text(CurrencyUtils.format(total, currency))),
                    ]),
                  ]))),
      heading(day == today ? 'Today · $day' : 'Itinerary · $day'),
      if (activities.isEmpty && bookings.isEmpty)
        empty('Nothing scheduled. Start with places or add an activity.'),
      ...bookings.map((i) => card(trip, plan, i)),
      ...activities.map((i) => card(trip, plan, i)),
      if (upcoming.isNotEmpty) ...[
        heading('Upcoming bookings'),
        ...upcoming.take(5).map((i) => card(trip, plan, i)),
      ],
      heading('Before you go'),
      if (outstanding.isEmpty)
        const Text('All preparation items are complete.'),
      ...outstanding.take(5).map((t) => taskTile(trip, plan, t)),
      if (deadlines.isNotEmpty) ...[
        heading('Cancellation deadlines'),
        ...deadlines.take(5).map((i) => ListTile(
            leading: const Icon(Icons.event_busy),
            title: Text(i.title),
            subtitle: Text(i['cancelBy']),
            onTap: () => edit(trip, plan, i)))
      ],
      if (missingNights.isNotEmpty) ...[
        heading('Accommodation gaps'),
        const Text('Add a stay, or mark a night as not needing accommodation.'),
        ...missingNights.map((d) => ListTile(
            title: Text('Night of $d'),
            trailing: TextButton(
                onPressed: () => edit(
                    trip,
                    plan,
                    PlanItem.create('booking').copy({
                      'category': 'No accommodation needed',
                      'title': 'No accommodation needed',
                      'date': d,
                      'status': 'confirmed'
                    })),
                child: const Text('Not needed'))))
      ],
    ]);
  }

  Widget itinerary(Trip trip, TripPlan plan) {
    final dayKeys =
        tripDays(trip.startDate, trip.endDate).map(planDate).toList();
    final extra = plan
        .ofKind('activity')
        .map((i) => i['date'])
        .where((d) => d.isNotEmpty && !dayKeys.contains(d))
        .toSet()
        .toList()
      ..sort();
    final choices = ['', ...dayKeys, ...extra];
    final day = selectedDay ??
        (dayKeys.contains(planDate(DateTime.now()))
            ? planDate(DateTime.now())
            : dayKeys.first);
    final items =
        plan.ofKind('activity').where((i) => i['date'] == day).toList();
    final bookings = day.isEmpty ? <PlanItem>[] : plan.bookingsOn(day);
    return page([
      Row(children: [
        Expanded(
            child: DropdownButtonFormField<String>(
                key: ValueKey(day),
                initialValue: choices.contains(day) ? day : '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Day'),
                items: choices
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(d.isEmpty ? 'Unassigned' : d)))
                    .toList(),
                onChanged: (d) => setState(() => selectedDay = d))),
        const SizedBox(width: 12),
        IconButton.filled(
            tooltip: 'Add activity',
            onPressed: () => edit(
                trip, plan, PlanItem.create('activity').copy({'date': day})),
            icon: const Icon(Icons.add))
      ]),
      if (bookings.isNotEmpty) ...[
        heading('Bookings · local times'),
        ...bookings.map((i) => card(trip, plan, i))
      ],
      heading('Activities',
          trailing: const Tooltip(
              message:
                  'Drag handles to change order; edit an item to move it to another day.',
              child: Icon(Icons.drag_indicator))),
      if (items.isEmpty)
        empty(day.isEmpty
            ? 'No unassigned activities.'
            : 'No activities yet. Add a place or a flexible activity.'),
      ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          // Retain compatibility with the Flutter 3.41 build used in CI.
          // ignore: deprecated_member_use
          onReorder: (oldIndex, newIndex) {
            final ids = items.map((i) => i.id).toList();
            if (newIndex > oldIndex) newIndex--;
            ids.insert(newIndex, ids.removeAt(oldIndex));
            action(() =>
                ref.read(tripPlanRepositoryProvider).reorder(trip.id, ids));
          },
          itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey(items[index].id),
              child: card(trip, plan, items[index],
                  handle: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle)))))),
      const SizedBox(height: 80),
    ]);
  }

  Widget places(Trip trip, TripPlan plan) {
    final items = plan
        .ofKind('place')
        .where((i) =>
            (category == 'All' || category == i['category']) &&
            (priority == 'All' || priority == i['priority']) &&
            (scheduled == 'All' ||
                (scheduled == 'Scheduled') == plan.isScheduled(i.id)))
        .toList();
    return page([
      heading('Places to eat, explore and shop',
          trailing: IconButton.filled(
              tooltip: 'Add place',
              onPressed: () => edit(trip, plan, PlanItem.create('place')),
              icon: const Icon(Icons.add))),
      Wrap(spacing: 12, runSpacing: 12, children: [
        filter('Category', category, ['All', ...placeCategories],
            (v) => setState(() => category = v)),
        filter('Priority', priority, ['All', ...planPriorities],
            (v) => setState(() => priority = v)),
        filter('Itinerary', scheduled, ['All', 'Scheduled', 'Unscheduled'],
            (v) => setState(() => scheduled = v))
      ]),
      const SizedBox(height: 12),
      if (items.isEmpty) empty('Save somewhere you want to go, eat or shop.'),
      ...items.map((i) => card(trip, plan, i)),
    ]);
  }

  Widget bookings(Trip trip, TripPlan plan) {
    final items = plan.ofKind('booking').toList()
      ..sort((a, b) => a['date'].compareTo(b['date']));
    return page([
      heading('Stays, transport and reservations',
          trailing: IconButton.filled(
              tooltip: 'Add booking',
              onPressed: () => edit(trip, plan, PlanItem.create('booking')),
              icon: const Icon(Icons.add))),
      const Text(
          'Booking details are saved offline. Payments remain in Expenses.'),
      if (items.isEmpty)
        empty('Add your first accommodation or transport booking.'),
      ...items.map((i) => card(trip, plan, i)),
    ]);
  }

  Widget taskTile(Trip trip, TripPlan plan, PlanItem item) => Card(
          child: ListTile(
        leading: Checkbox(
            value: item['status'] == 'completed',
            onChanged: (v) => action(() => ref
                .read(tripPlanRepositoryProvider)
                .save(trip.id,
                    item.copy({'status': v! ? 'completed' : 'todo'})))),
        title: Text(item.title,
            style: TextStyle(
                decoration: item['status'] == 'completed'
                    ? TextDecoration.lineThrough
                    : null)),
        subtitle: Text(
            [
              item['category'],
              if (item['date'].isNotEmpty) 'Due ${item['date']}',
              item['assignee'],
              item['notes']
            ].where((v) => v.isNotEmpty).join(' · '),
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
        onTap: () => edit(trip, plan, item),
        trailing: IconButton(
            tooltip: 'Delete checklist item',
            onPressed: () => remove(trip, item),
            icon: const Icon(Icons.delete_outline)),
      ));
  Widget preparation(Trip trip, TripPlan plan) {
    final items = plan
        .ofKind('task')
        .where((i) => checklist == 'All' || i['category'] == checklist)
        .toList();
    return page([
      heading('Get ready',
          trailing: IconButton.filled(
              tooltip: 'Add checklist item',
              onPressed: () => edit(
                  trip,
                  plan,
                  PlanItem.create('task').copy({
                    'category': checklist == 'All' ? 'Preparation' : checklist
                  })),
              icon: const Icon(Icons.add))),
      Wrap(
          spacing: 8,
          children: ['All', ...taskCategories]
              .map((v) => ChoiceChip(
                  label: Text(v),
                  selected: v == checklist,
                  onSelected: (_) => setState(() => checklist = v)))
              .toList()),
      if (items.isEmpty) empty('Add preparation, packing or shopping items.'),
      ...items.map((i) => taskTile(trip, plan, i)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final planAsync = ref.watch(tripPlanProvider(widget.tripId));
    return tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return Scaffold(
                appBar: AppBar(title: const Text('Trip')),
                body: const Center(child: Text('Trip not found')));
          }
          return planAsync.when(
              data: (plan) => DefaultTabController(
                  length: 6,
                  child: Scaffold(
                    appBar: AppBar(
                        title: Text(trip.destination),
                        actions: [
                          IconButton(
                              tooltip: 'Sync trip',
                              icon: const Icon(Icons.sync),
                              onPressed: () => action(() => ref
                                  .read(syncStateProvider.notifier)
                                  .syncNow())),
                          IconButton(
                              tooltip: 'Delete trip',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final yes = await showDeleteConfirmDialog(
                                    context,
                                    title: 'Delete trip',
                                    content:
                                        'Delete this trip, its plan, bookings, checklists and expenses?');
                                if (yes && mounted) {
                                  await action(() async {
                                    await ref
                                        .read(travelRepositoryProvider)
                                        .deleteTrip(trip.id);
                                    if (context.mounted) Navigator.pop(context);
                                  });
                                }
                              }),
                        ],
                        bottom: const TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              Tab(text: 'Overview'),
                              Tab(text: 'Itinerary'),
                              Tab(text: 'Places'),
                              Tab(text: 'Bookings'),
                              Tab(text: 'Preparation'),
                              Tab(text: 'Expenses')
                            ])),
                    body: Column(children: [
                      if (plan.pending || plan.error.isNotEmpty)
                        Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(plan.error == 'conflict'
                                          ? 'This trip plan changed on another device. Choose which complete version to keep.'
                                          : plan.error.isNotEmpty
                                              ? plan.error
                                              : 'Saved on this device · pending sync'),
                                      if (plan.error == 'conflict')
                                        Wrap(spacing: 8, children: [
                                          TextButton(
                                              onPressed: resolving
                                                  ? null
                                                  : () => resolve(true),
                                              child: const Text(
                                                  'Keep this device')),
                                          TextButton(
                                              onPressed: resolving
                                                  ? null
                                                  : () => resolve(false),
                                              child: const Text(
                                                  'Use server version'))
                                        ]),
                                      if (plan.error.isNotEmpty &&
                                          plan.error != 'conflict')
                                        Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton(
                                                onPressed: () => action(() => ref
                                                    .read(
                                                        tripPlanRepositoryProvider)
                                                    .sync(trip.id)),
                                                child:
                                                    const Text('Retry sync'))),
                                    ]))),
                      Expanded(
                          child: TabBarView(children: [
                        overview(trip, plan),
                        itinerary(trip, plan),
                        places(trip, plan),
                        bookings(trip, plan),
                        preparation(trip, plan),
                        TripExpensesScreen(tripId: trip.id)
                      ])),
                    ]),
                  )),
              loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator())),
              error: (e, _) => Scaffold(
                  appBar: AppBar(title: Text(trip.destination)),
                  body: Center(child: Text('Could not load plan: $e'))));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Trip')),
            body: Center(child: Text('Could not load trip: $e'))));
  }
}
