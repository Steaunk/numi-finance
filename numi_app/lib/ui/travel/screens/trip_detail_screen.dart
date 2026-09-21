import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../providers/providers.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/dialogs.dart';
import '../widgets/plan_item_editor.dart';
import '../widgets/plan_links.dart';
import '../widgets/travel_surfaces.dart';
import 'trip_expenses_screen.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});
  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String? selectedDay;
  String category = 'All', priority = 'All', scheduled = 'All';
  bool reordering = false, resolving = false;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(tripPlanRepositoryProvider).sync(widget.tripId));
      }
    });
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  String dayFor(Trip trip) {
    final today = planDate(DateTime.now());
    return selectedDay ??
        (today.compareTo(planDate(trip.startDate)) < 0
            ? planDate(trip.startDate)
            : today.compareTo(planDate(trip.endDate)) > 0
                ? planDate(trip.endDate)
                : today);
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

  Future<void> remove(
      Trip trip, PlanItem item, BuildContext sheetContext) async {
    final yes = await showDeleteConfirmDialog(sheetContext,
        title: 'Delete ${item.kind}',
        content: item.kind == 'place'
            ? 'Remove this place? Linked activities will be kept.'
            : 'Remove this item from your plan?');
    if (yes && mounted) {
      await action(() async {
        await ref.read(tripPlanRepositoryProvider).remove(trip.id, item.id);
        if (sheetContext.mounted) Navigator.pop(sheetContext);
      });
    }
  }

  Future<void> moveDay(Trip trip, PlanItem item) async {
    var initial = DateTime.tryParse(item['date']) ?? trip.startDate;
    if (initial.isBefore(trip.startDate)) initial = trip.startDate;
    if (initial.isAfter(trip.endDate)) initial = trip.endDate;
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: trip.startDate,
        lastDate: trip.endDate,
        helpText: 'Move activity');
    if (date != null && mounted) {
      await action(() async {
        await ref
            .read(tripPlanRepositoryProvider)
            .save(trip.id, item.copy({'date': planDate(date)}));
        if (mounted) setState(() => selectedDay = planDate(date));
      });
    }
  }

  Widget section(String title, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 14),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.3))),
        if (action != null) action
      ]));
  Widget hint(String title, String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(message,
            style: TextStyle(
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));
  Widget tile(Trip trip, TripPlan plan, PlanItem item,
          {String? subtitle, bool tinted = false, Widget? trailing}) =>
      TravelTile(
          key: ValueKey('item-${item.id}'),
          title: plan.itemTitle(item),
          subtitle: subtitle ?? itemSubtitle(plan, item),
          icon: planIcon(plan.find(item['placeId']) ?? item),
          tinted: tinted,
          trailing: trailing,
          onTap: () => openItem(trip, item.id));
  String itemSubtitle(TripPlan plan, PlanItem item) {
    final place = plan.find(item['placeId']);
    return [
      place?['category'] ?? item['category'],
      if (item.kind == 'place')
        plan.isScheduled(item.id) ? 'Scheduled' : 'Not scheduled',
      if (item.kind == 'place' && item['priority'] == 'Must go') 'Must go',
      if (item.cancelled ||
          item['status'] == 'completed' ||
          item.kind == 'booking')
        item['status'],
      if (item.kind == 'booking' && item['date'].isNotEmpty)
        travelDate(item['date']),
      if (item.kind == 'booking' && item['endDate'].isNotEmpty)
        'to ${travelDate(item['endDate'])}',
      if (item.kind == 'activity' && item['time'].isEmpty) 'Flexible',
      if (item.kind == 'activity' && item['endTime'].isNotEmpty)
        'until ${item['endTime']}',
    ].where((v) => v.isNotEmpty).join(' · ');
  }

  void openItem(Trip trip, String id) {
    showTravelSheet(context,
        title: 'Details',
        builder: (sheetContext) => Consumer(
              builder: (context, ref, _) {
                final plan = ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                    TripPlan();
                final item = plan.find(id);
                if (item == null) {
                  return const Center(child: Text('This item was removed.'));
                }
                final place = plan.find(item['placeId']);
                final address = place?['address'] ?? item['address'];
                Widget detail(String label, String value) => value.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              const SizedBox(height: 5),
                              SelectableText(value,
                                  style: const TextStyle(
                                      fontSize: 15, height: 1.5)),
                            ]));
                Widget maps(String name, String address,
                        {bool arrival = false}) =>
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(spacing: 10, runSpacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: () => openPlanLink(context,
                                  mapSearchLink(name, address).toString()),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(arrival
                                  ? 'Arrival · Google Maps'
                                  : 'Google Maps')),
                          OutlinedButton.icon(
                              onPressed: () => openPlanLink(
                                  context,
                                  baiduMapSearchLink(
                                          name, address, trip.destination)
                                      .toString()),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(arrival
                                  ? 'Arrival · Baidu Maps'
                                  : 'Baidu Maps')),
                        ]));
                return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(plan.itemTitle(item),
                                    style: const TextStyle(
                                        fontSize: 27,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -.6))),
                            PopupMenuButton<String>(
                                tooltip: 'Item actions',
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    remove(trip, item, sheetContext);
                                  }
                                  if (value == 'move') moveDay(trip, item);
                                  if (value == 'unassign') {
                                    action(() => ref
                                        .read(tripPlanRepositoryProvider)
                                        .save(
                                            trip.id, item.copy({'date': ''})));
                                  }
                                  if (value == 'complete') {
                                    action(() => ref
                                        .read(tripPlanRepositoryProvider)
                                        .save(
                                            trip.id,
                                            item.copy(
                                                {'status': 'completed'})));
                                  }
                                },
                                itemBuilder: (_) => [
                                      if (item.kind == 'activity')
                                        const PopupMenuItem(
                                            value: 'move',
                                            child: Text('Move to another day')),
                                      if (item.kind == 'activity' &&
                                          item['date'].isNotEmpty)
                                        const PopupMenuItem(
                                            value: 'unassign',
                                            child: Text('Leave unassigned')),
                                      if (item['status'] != 'completed')
                                        const PopupMenuItem(
                                            value: 'complete',
                                            child: Text('Mark completed')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete item')),
                                    ]),
                          ]),
                      const SizedBox(height: 10),
                      Text(itemSubtitle(plan, item),
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      detail(
                          item.kind == 'booking'
                              ? 'Start · local time'
                              : 'Scheduled',
                          [item['date'], item['time'], item['timezone']]
                              .where((v) => v.isNotEmpty)
                              .join(' · ')),
                      detail(
                          'End · local time',
                          [
                            item['endDate'],
                            item['endTime'],
                            item['endTimezone']
                          ].where((v) => v.isNotEmpty).join(' · ')),
                      detail('Address', address),
                      if (address.isNotEmpty || item.kind == 'place')
                        maps(place?.title ?? plan.itemTitle(item), address),
                      detail('Arrival address', item['endAddress']),
                      if (item['endAddress'].isNotEmpty)
                        maps('', item['endAddress'], arrival: true),
                      detail('Confirmation', item['confirmation']),
                      detail('Contact', item['contact']),
                      detail('Cancellation deadline', item['cancelBy']),
                      detail('Responsible person', item['assignee']),
                      detail('Notes', item['notes']),
                      if (place != null) detail('Place notes', place['notes']),
                      if ([...?place?.links, ...item.links].isNotEmpty) ...[
                        section('Links'),
                        PlanLinks(links: [...?place?.links, ...item.links]),
                      ],
                      const SizedBox(height: 26),
                      if (item.kind == 'place')
                        FilledButton.icon(
                            onPressed: () => edit(
                                trip,
                                plan,
                                PlanItem.create('activity').copy({
                                  'placeId': item.id,
                                  'date': dayFor(trip)
                                })),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add to itinerary')),
                      TextButton.icon(
                          onPressed: () => edit(trip, plan, item),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(
                              'Edit ${item.kind == 'task' ? 'checklist item' : item.kind}')),
                    ]);
              },
            ));
  }

  void openPanel(Trip trip, String panel) {
    var checklist = 'All';
    showTravelSheet(context,
        title: switch (panel) {
          'bookings' => 'Your bookings',
          'preparation' => 'Before you go',
          _ => 'Trip spending'
        }, builder: (sheetContext) {
      if (panel == 'expenses') return TripExpensesScreen(tripId: trip.id);
      return StatefulBuilder(
          builder: (context, update) => Consumer(builder: (context, ref, _) {
                final plan = ref.watch(tripPlanProvider(trip.id)).valueOrNull ??
                    TripPlan();
                if (panel == 'bookings') {
                  final records = plan.ofKind('booking')
                    ..sort((a, b) => a['date'].compareTo(b['date']));
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      children: [
                        Text('Stays, transport and reservations',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        const SizedBox(height: 16),
                        ...records.map((i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: tile(trip, plan, i))),
                        if (records.isEmpty)
                          hint('A place for every booking',
                              'Keep tickets, confirmation numbers and accommodation together.'),
                        FilledButton.icon(
                            onPressed: () => edit(
                                trip,
                                plan,
                                PlanItem.create('booking').copy({
                                  'date': dayFor(trip).isEmpty
                                      ? planDate(trip.startDate)
                                      : dayFor(trip)
                                })),
                            icon: const Icon(Icons.add),
                            label: const Text('Add booking')),
                      ]);
                }
                final tasks = plan
                    .ofKind('task')
                    .where(
                        (i) => checklist == 'All' || i['category'] == checklist)
                    .toList();
                return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    children: [
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['All', ...taskCategories]
                              .map((c) => ChoiceChip(
                                  label: Text(c),
                                  selected: checklist == c,
                                  onSelected: (_) =>
                                      update(() => checklist = c)))
                              .toList()),
                      const SizedBox(height: 18),
                      ...tasks.map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                              color: travelSurface(context),
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                leading: Checkbox(
                                    value: i['status'] == 'completed',
                                    onChanged: (v) => action(() => ref
                                        .read(tripPlanRepositoryProvider)
                                        .save(
                                            trip.id,
                                            i.copy({
                                              'status':
                                                  v! ? 'completed' : 'todo'
                                            })))),
                                title: Text(i.title,
                                    style: TextStyle(
                                        decoration: i['status'] == 'completed'
                                            ? TextDecoration.lineThrough
                                            : null)),
                                subtitle: Text([
                                  i['category'],
                                  if (i['date'].isNotEmpty)
                                    'Due ${travelDate(i['date'])}',
                                  i['assignee']
                                ].where((v) => v.isNotEmpty).join(' · ')),
                                onTap: () => openItem(trip, i.id),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 18),
                              )))),
                      if (tasks.isEmpty)
                        hint('Travel a little lighter',
                            'Add preparation, packing or shopping reminders.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed: () => edit(
                              trip,
                              plan,
                              PlanItem.create('task').copy({
                                'category': checklist == 'All'
                                    ? 'Preparation'
                                    : checklist
                              })),
                          icon: const Icon(Icons.add),
                          label: const Text('Add checklist item')),
                    ]);
              }));
    });
  }

  Future<void> filters() async {
    var c = category, p = priority, s = scheduled;
    final apply = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => StatefulBuilder(builder: (context, update) {
              Widget choice(String label, String value, List<String> choices,
                      ValueChanged<String> change) =>
                  Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: DropdownButtonFormField<String>(
                          initialValue: value,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: label),
                          items: choices
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => update(() => change(v!))));
              return SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Filter saved places',
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                            choice('Category', c, ['All', ...placeCategories],
                                (v) => c = v),
                            choice('Priority', p, ['All', ...planPriorities],
                                (v) => p = v),
                            choice(
                                'Itinerary',
                                s,
                                ['All', 'Scheduled', 'Unscheduled'],
                                (v) => s = v),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Apply filters')),
                            TextButton(
                                onPressed: () {
                                  c = p = s = 'All';
                                  Navigator.pop(context, true);
                                },
                                child: const Text('Clear filters')),
                          ])));
            }));
    if (apply == true && mounted) {
      setState(() {
        category = c;
        priority = p;
        scheduled = s;
      });
    }
  }

  Future<void> addToDay(Trip trip, TripPlan plan) async {
    final choice = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      leading: const Icon(Icons.bookmarks_outlined),
                      title: const Text('Choose a saved place'),
                      subtitle:
                          const Text('Restaurants, shops and places you love'),
                      onTap: () => Navigator.pop(context, 'place')),
                  ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: const Text('Add an activity'),
                      subtitle:
                          const Text('A walk, free time or something new'),
                      onTap: () => Navigator.pop(context, 'activity')),
                  ListTile(
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: const Text('Add transport or a stay'),
                      onTap: () => Navigator.pop(context, 'booking')),
                ]))));
    if (!mounted || choice == null) return;
    if (choice == 'place') {
      tabs.animateTo(1);
      return;
    }
    await edit(
        trip, plan, PlanItem.create(choice).copy({'date': dayFor(trip)}));
  }

  Widget timeline(Trip trip, TripPlan plan) {
    final day = dayFor(trip);
    final days = {
      ...tripDays(trip.startDate, trip.endDate).map(planDate),
      ...plan
          .ofKind('activity')
          .map((i) => i['date'])
          .where((d) => d.isNotEmpty)
    }.toList()
      ..sort();
    final activities =
        plan.ofKind('activity').where((i) => i['date'] == day).toList();
    final bookings = day.isEmpty
        ? <PlanItem>[]
        : plan
            .bookingsOn(day)
            .where((i) =>
                i['category'] != 'No accommodation needed' &&
                (i['category'] != 'Accommodation' || i['endDate'] == day))
            .toList();
    String time(PlanItem i) =>
        i.kind == 'booking' && i['endDate'] == day && i['date'] != day
            ? i['endTime']
            : i['time'];
    bookings.sort((a, b) => time(a).compareTo(time(b)));
    final entries = [...activities];
    for (final booking in bookings) {
      final index = entries.indexWhere((i) =>
          time(i).isEmpty ||
          (time(booking).isNotEmpty && time(i).compareTo(time(booking)) > 0));
      entries.insert(index < 0 ? entries.length : index, booking);
    }
    Widget row(PlanItem item, {Widget? handle}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 44,
              child: Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Text(time(item).isEmpty ? 'Anytime' : time(item),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)))),
          const SizedBox(width: 10),
          Expanded(child: tile(trip, plan, item, trailing: handle)),
        ]));
    final stays = day.isEmpty
        ? <PlanItem>[]
        : plan
            .ofKind('booking')
            .where((i) =>
                !i.cancelled &&
                (i['category'] == 'Accommodation' &&
                        i['date'].compareTo(day) <= 0 &&
                        i['endDate'].compareTo(day) > 0 ||
                    i['category'] == 'No accommodation needed' &&
                        i['date'] == day))
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 20),
      TripDayStrip(
          days: days,
          selected: day,
          unassigned:
              plan.ofKind('activity').where((i) => i['date'].isEmpty).length,
          onSelected: (v) => setState(() {
                selectedDay = v;
                reordering = false;
              })),
      section(
          day.isEmpty
              ? 'Waiting for a day'
              : DateFormat('EEEE, d MMM').format(DateTime.parse(day)),
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            if (activities.length > 1)
              IconButton(
                  tooltip:
                      reordering ? 'Finish reordering' : 'Reorder activities',
                  onPressed: () => setState(() => reordering = !reordering),
                  icon: Icon(reordering ? Icons.check : Icons.swap_vert,
                      size: 21)),
            IconButton(
                tooltip: 'Choose date',
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(day)
                                      ?.isBefore(trip.startDate) ==
                                  false &&
                              DateTime.tryParse(day)?.isAfter(trip.endDate) ==
                                  false
                          ? DateTime.parse(day)
                          : trip.startDate,
                      firstDate: trip.startDate,
                      lastDate: trip.endDate);
                  if (date != null && mounted) {
                    if (mounted) setState(() => selectedDay = planDate(date));
                  }
                }),
          ])),
      if (reordering) ...[
        const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
                'Drag to arrange activities. Bookings keep their recorded times.',
                style: TextStyle(fontSize: 12))),
        ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: activities.length,
            // Keep compatibility with the Flutter 3.41 CI toolchain.
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              final ids = activities.map((i) => i.id).toList();
              if (newIndex > oldIndex) newIndex--;
              ids.insert(newIndex, ids.removeAt(oldIndex));
              action(() =>
                  ref.read(tripPlanRepositoryProvider).reorder(trip.id, ids));
            },
            itemBuilder: (context, index) => KeyedSubtree(
                key: ValueKey(activities[index].id),
                child: row(activities[index],
                    handle: ReorderableDragStartListener(
                        index: index,
                        child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.all(10),
                            child: const Icon(Icons.drag_handle, size: 20))))))
      ] else
        ...entries.map((i) => row(i)),
      if (entries.isEmpty)
        hint(
            day.isEmpty
                ? 'Room for a little spontaneity'
                : 'Make this day yours',
            'Choose a saved place or add a flexible activity to get started.'),
      if (!reordering)
        ...stays.map((i) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: tile(trip, plan, i,
                tinted: true,
                subtitle: i['category'] == 'No accommodation needed'
                    ? 'Overnight travel · no stay needed'
                    : 'Your stay · ${travelDate(i['date'])}–${travelDate(i['endDate'])}'))),
      if (day.isNotEmpty &&
          day.compareTo(planDate(trip.endDate)) < 0 &&
          !plan.hasStay(day))
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Icons.bedtime_outlined, size: 20),
                title: const Text('No stay planned',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text('Add a stay or mark overnight travel.',
                    style: TextStyle(fontSize: 12)),
                onTap: () => edit(
                    trip, plan, PlanItem.create('booking').copy({'date': day})),
                trailing: PopupMenuButton<String>(
                    tooltip: 'Stay options',
                    onSelected: (_) => edit(
                        trip,
                        plan,
                        PlanItem.create('booking').copy({
                          'title': 'No accommodation needed',
                          'category': 'No accommodation needed',
                          'date': day,
                          'status': 'confirmed'
                        })),
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'none',
                              child: Text('No accommodation needed'))
                        ]))),
      const SizedBox(height: 10),
      TextButton.icon(
          onPressed: () => addToDay(trip, plan),
          icon: const Icon(Icons.add, size: 19),
          label: const Text('Add to this day')),
    ]);
  }

  Widget places(Trip trip, TripPlan plan) {
    final records = plan
        .ofKind('place')
        .where((i) =>
            (category == 'All' || category == i['category']) &&
            (priority == 'All' || priority == i['priority']) &&
            (scheduled == 'All' ||
                (scheduled == 'Scheduled') == plan.isScheduled(i.id)))
        .toList();
    final active =
        [category, priority, scheduled].where((s) => s != 'All').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section('Places to explore',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: 'Filter places',
                onPressed: filters,
                icon: Icon(active.isEmpty ? Icons.tune : Icons.filter_alt,
                    size: 21)),
            IconButton(
                tooltip: 'Add place',
                onPressed: () => edit(trip, plan, PlanItem.create('place')),
                icon: const Icon(Icons.add, size: 23)),
          ])),
      if (active.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(spacing: 8, children: [
              ...active.map((s) => Chip(label: Text(s))),
              TextButton(
                  onPressed: () => setState(() {
                        category = priority = scheduled = 'All';
                      }),
                  child: const Text('Clear')),
            ])),
      if (records.isEmpty)
        hint('Somewhere you want to go',
            'Save restaurants, coffee shops and places worth a detour. Add them to a day when you are ready.'),
      LayoutBuilder(
          builder: (context, constraints) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: records
                  .map((i) => SizedBox(
                      width: constraints.maxWidth >= 660
                          ? (constraints.maxWidth - 14) / 2
                          : constraints.maxWidth,
                      child: tile(trip, plan, i)))
                  .toList())),
    ]);
  }

  Future<void> resolve(bool keepLocal) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(
                    keepLocal ? 'Replace server plan?' : 'Use server plan?'),
                content: Text(keepLocal
                    ? 'Replace the complete server plan with this device’s version?'
                    : 'Replace this device’s plan with the server version? Unsynced changes will be discarded.'),
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

  Widget syncNotice(TripPlan plan) {
    if (plan.error.isEmpty) return const SizedBox.shrink();
    return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: .5),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.error == 'conflict'
              ? 'This plan changed on another device. Choose which version to keep.'
              : plan.error),
          Wrap(
              spacing: 8,
              children: plan.error == 'conflict'
                  ? [
                      TextButton(
                          onPressed: resolving ? null : () => resolve(true),
                          child: const Text('Keep this device')),
                      TextButton(
                          onPressed: resolving ? null : () => resolve(false),
                          child: const Text('Use server version')),
                    ]
                  : [
                      TextButton(
                          onPressed: () => action(() => ref
                              .read(tripPlanRepositoryProvider)
                              .sync(widget.tripId)),
                          child: const Text('Retry sync'))
                    ]),
        ]));
  }

  Widget header(Trip trip, TripPlan plan) {
    final colors = Theme.of(context).colorScheme;
    final currency = ref.watch(displayCurrencyProvider);
    final total = trip.expenses
        .fold<double>(0, (sum, e) => sum + e.displayAmount(currency));
    final tasks = plan.ofKind('task');
    Widget shortcut(String tooltip, IconData icon, String text, String panel) =>
        Tooltip(
            message: tooltip,
            child: TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 12)),
                onPressed: () => openPanel(trip, panel),
                icon: Icon(icon, size: 17),
                label: Text(text)));
    final deadlines = plan
        .ofKind('booking')
        .where((i) =>
            !i.cancelled &&
            i['cancelBy'].isNotEmpty &&
            i['cancelBy'].compareTo(planDate(DateTime.now())) >= 0)
        .toList()
      ..sort((a, b) => a['cancelBy'].compareTo(b['cancelBy']));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(tripPhase(trip.startDate, trip.endDate, DateTime.now()),
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1))),
        if (plan.pending)
          Tooltip(
              message: 'Saved on this device · pending sync',
              child: Icon(Icons.cloud_off_outlined,
                  size: 16, color: colors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 9),
      Text(trip.destination,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text(
          '${DateFormat('d MMM').format(trip.startDate)} – ${DateFormat('d MMM yyyy').format(trip.endDate)} · ${tripDays(trip.startDate, trip.endDate).length} days',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 0, children: [
        shortcut('View bookings', Icons.confirmation_number_outlined,
            '${plan.ofKind('booking').length} bookings', 'bookings'),
        shortcut(
            'View preparation',
            Icons.task_alt,
            '${tasks.where((i) => i['status'] == 'completed').length}/${tasks.length} ready',
            'preparation'),
        shortcut('View expenses', Icons.account_balance_wallet_outlined,
            CurrencyUtils.format(total, currency), 'expenses'),
      ]),
      if (deadlines.isNotEmpty &&
          deadlines.first['cancelBy'].compareTo(
                  planDate(DateTime.now().add(const Duration(days: 7)))) <=
              0)
        TextButton.icon(
            onPressed: () => openItem(trip, deadlines.first.id),
            icon: const Icon(Icons.event_busy, size: 16),
            label: Text(
                'Cancellation deadline · ${travelDate(deadlines.first['cancelBy'])}',
                style: const TextStyle(fontSize: 12))),
      const SizedBox(height: 12),
      syncNotice(plan),
    ]);
  }

  Future<void> tripMenu(String value, Trip trip) async {
    if (value == 'sync') {
      await action(() => ref.read(syncStateProvider.notifier).syncNow());
      return;
    }
    if (value == 'notes') {
      await showTravelSheet(context,
          title: 'Trip notes',
          builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                  trip.notes.isEmpty ? 'No trip notes yet.' : trip.notes)));
    }
    if (value == 'delete' && mounted) {
      final yes = await showDeleteConfirmDialog(context,
          title: 'Delete trip',
          content:
              'Delete this trip, its plan, bookings, checklists and expenses?');
      if (yes && mounted) {
        await action(() async {
          await ref.read(travelRepositoryProvider).deleteTrip(trip.id);
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final planAsync = ref.watch(tripPlanProvider(widget.tripId));
    return tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return Scaffold(
                appBar: AppBar(),
                body: const Center(child: Text('Trip not found')));
          }
          return planAsync.when(
              data: (plan) => Scaffold(
                    backgroundColor: travelBackground(context),
                    appBar: AppBar(title: const Text('Trip details'), actions: [
                      PopupMenuButton<String>(
                          tooltip: 'Trip options',
                          onSelected: (value) => tripMenu(value, trip),
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'sync', child: Text('Sync trip')),
                                PopupMenuItem(
                                    value: 'notes', child: Text('Trip notes')),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete trip')),
                              ])
                    ]),
                    body: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: ListView(
                                key:
                                    PageStorageKey('trip-workspace-${trip.id}'),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                children: [
                                  header(trip, plan),
                                  TabBar(
                                      controller: tabs,
                                      isScrollable: true,
                                      tabAlignment: TabAlignment.start,
                                      labelPadding:
                                          const EdgeInsets.only(right: 28),
                                      dividerColor: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: .5),
                                      tabs: const [
                                        Tab(text: 'Itinerary'),
                                        Tab(text: 'Saved places')
                                      ]),
                                  if (tabs.index == 0)
                                    timeline(trip, plan)
                                  else
                                    places(trip, plan),
                                ]))),
                  ),
              loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator())),
              error: (e, _) => Scaffold(
                  appBar: AppBar(),
                  body: Center(child: Text('Could not load plan: $e'))));
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Could not load trip: $e'))));
  }
}
