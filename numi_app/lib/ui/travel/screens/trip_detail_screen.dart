import 'dart:async';
import 'package:intl/intl.dart';
import '../widgets/travel_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import '../../../models/travel_expense.dart';
import '../../../providers/providers.dart';
import '../../../data/repositories/trip_plan_repository.dart';
import '../../../utils/currency_utils.dart';
import '../../common/widgets/amount_display.dart';
import '../../common/widgets/dialogs.dart';
import '../../common/widgets/sync_status_indicator.dart';
import '../widgets/plan_editors.dart';
import '../widgets/plan_map.dart';
import '../widgets/plan_export.dart';
import 'add_travel_expense_screen.dart';

class TripDetailScreen extends StatelessWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});
  @override
  Widget build(BuildContext context) =>
      TravelTheme(child: _TripDetailBody(tripId: tripId));
}

class _TripDetailBody extends ConsumerStatefulWidget {
  final int tripId;
  const _TripDetailBody({required this.tripId});
  @override
  ConsumerState<_TripDetailBody> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<_TripDetailBody> {
  String? selectedDay;
  String query = '';
  bool unplannedOnly = false;
  bool allMapPlaces = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(tripPlanRepositoryProvider).sync());
    });
  }

  Future<void> change(void Function(TripPlan) edit) async {
    try {
      await ref.read(tripPlanRepositoryProvider).edit(widget.tripId, edit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  List<String> daysFor(Trip trip, TripPlan plan) => {
        ...tripDates(trip.startDate, trip.endDate),
        ...plan.entries.where((e) => e.date.isNotEmpty).expand((e) => tripDates(
            DateTime.parse(e.date),
            DateTime.parse(e.endDate.isEmpty ? e.date : e.endDate)))
      }.toList()
        ..sort();
  void undo(String message, void Function(TripPlan) edit) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: () => change(edit))));
  }

  Future<void> addOrEdit(Trip trip, TripPlan plan,
      {PlanEntry? entry, PlanPlace? place}) async {
    final result = await editEntry(context,
        plan: plan,
        days: daysFor(trip, plan),
        entry: entry,
        date: selectedDay ?? planDate(trip.startDate),
        place: place);
    if (result != null && mounted) await change((p) => p.saveEntry(result));
  }

  Future<void> placeEditor({PlanPlace? place, double? lat, double? lng}) async {
    final result = await editPlace(context, place: place, lat: lat, lng: lng);
    if (result != null && mounted) await change((p) => p.savePlace(result));
  }

  Future<void> expense(Trip trip, {TravelExpense? expense, PlanEntry? entry}) =>
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => AddTravelExpenseScreen(
              tripId: trip.id,
              tripStartDate: trip.startDate,
              tripEndDate: trip.endDate,
              expense: expense,
              initialName: entry?.title,
              initialCategory: entry?.category,
              initialDate: entry?.date.isNotEmpty == true
                  ? DateTime.parse(entry!.date)
                  : null,
              plannerEntryId: entry?.id));

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final planAsync = ref.watch(tripPlanProvider(widget.tripId));
    return tripAsync.when(
      loading: () => Scaffold(
          appBar: AppBar(title: const Text('Trip')),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Trip')),
          body: Center(child: Text('Could not load trip: $e'))),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Trip')),
              body: const Center(child: Text('Trip not found')));
        }
        return planAsync.when(
          loading: () => Scaffold(
              appBar: AppBar(title: Text(trip.destination)),
              body: const Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
              appBar: AppBar(title: Text(trip.destination)),
              body: Center(child: Text('Could not load plan: $e'))),
          data: (state) {
            final plan = state.plan;
            final days = daysFor(trip, plan);
            final day = selectedDay != null &&
                    (selectedDay!.isEmpty || days.contains(selectedDay))
                ? selectedDay!
                : days.first;
            final scrollTabs = MediaQuery.sizeOf(context).width /
                    MediaQuery.textScalerOf(context).scale(1) <
                360;
            return DefaultTabController(
                length: 5,
                child: Scaffold(
                  appBar: AppBar(
                      title: Text(trip.destination),
                      actions: [
                        const SyncStatusIndicator(),
                        IconButton(
                            tooltip: 'Share itinerary',
                            icon: const Icon(Icons.ios_share),
                            onPressed: () =>
                                showPlanExport(context, trip, plan)),
                        PopupMenuButton<String>(
                            onSelected: (_) async {
                              final confirmed = await showDeleteConfirmDialog(
                                  context,
                                  title: 'Delete Trip',
                                  content:
                                      'Delete "${trip.destination}" and its plan and expenses?');
                              if (confirmed && mounted) {
                                await ref
                                    .read(travelRepositoryProvider)
                                    .deleteTrip(trip.id);
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete trip'))
                                ]),
                      ],
                      bottom: TabBar(
                          isScrollable: scrollTabs,
                          tabAlignment: scrollTabs
                              ? TabAlignment.start
                              : TabAlignment.fill,
                          labelPadding: EdgeInsets.symmetric(
                              horizontal: scrollTabs ? 14 : 4),
                          labelStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          tabs: const [
                            Tab(text: 'Itinerary'),
                            Tab(text: 'Places'),
                            Tab(text: 'Map'),
                            Tab(text: 'Lists'),
                            Tab(text: 'Expenses')
                          ])),
                  body: TravelPageWidth(
                      child: Column(children: [
                    if (state.conflict != null)
                      _conflictBanner(state)
                    else if (state.pending || state.error != null)
                      Container(
                          width: double.infinity,
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 0),
                          child: Row(children: [
                            const Icon(Icons.cloud_upload_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    state.error ??
                                        'Saved on this device · waiting to sync',
                                    style:
                                        Theme.of(context).textTheme.bodySmall)),
                            TextButton(
                                onPressed: () =>
                                    ref.read(tripPlanRepositoryProvider).sync(),
                                child: const Text('Retry'))
                          ])),
                    Expanded(
                        child: TabBarView(children: [
                      _itinerary(trip, plan, days, day),
                      _places(trip, plan),
                      Column(children: [
                        SwitchListTile(
                            title: const Text('Show all saved places'),
                            subtitle: Text(allMapPlaces
                                ? 'Including places not yet scheduled'
                                : (day.isEmpty
                                    ? 'Select a day in Itinerary to filter'
                                    : day)),
                            value: allMapPlaces,
                            onChanged: (v) => setState(() => allMapPlaces = v)),
                        if (!allMapPlaces) _daySelector(days, day),
                        Expanded(
                            child: PlanMap(
                                plan: plan,
                                day: allMapPlaces || day.isEmpty ? null : day,
                                onAdd: (lat, lng) =>
                                    placeEditor(lat: lat, lng: lng),
                                onPlace: (place) =>
                                    _placeActions(trip, plan, place))),
                      ]),
                      _lists(plan),
                      _expenses(trip, plan),
                    ])),
                  ])),
                ));
          },
        );
      },
    );
  }

  Widget _conflictBanner(PlanState state) => Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'This trip plan changed on another device. Both versions are saved.'),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Compare plans'),
                              content: SizedBox(
                                  width: 500,
                                  child: SingleChildScrollView(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(_planSummary(
                                            'On this device', state.plan)),
                                        const Divider(),
                                        Text(_planSummary(
                                            'On the server', state.conflict!))
                                      ]))),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'))
                              ])),
                  child: const Text('Compare')),
              TextButton(
                  onPressed: () => _resolve(true),
                  child: const Text('Keep this device')),
              TextButton(
                  onPressed: () => _resolve(false),
                  child: const Text('Use server version')),
            ]),
          ])));
  String _planSummary(String title, TripPlan plan) =>
      '$title\n${plan.places.length} places · ${plan.entries.length} activities · ${plan.checks.length} list items\n${plan.entries.map((e) => '${e.date.isEmpty ? 'Unscheduled' : e.date} ${e.time} ${e.timezone} ${e.title} · ${e.status}\nUntil ${e.endDate} ${e.endTime} ${e.endTimezone}\n${plan.place(e.placeId)?.title ?? ''}\n${e.confirmation} ${e.url}\n${e.notes}').join('\n')}\n${plan.places.map((p) => '${p.title} ${p.address} (${p.lat ?? ''}, ${p.lng ?? ''}) ${p.url} ${p.notes}').join('\n')}\n${plan.checks.map((c) => '${c.done ? '✓' : '○'} ${c.title} ${c.due}').join('\n')}\n${plan.dayNotes.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
  Future<void> _resolve(bool mine) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(mine
                    ? 'Keep this device’s plan?'
                    : 'Use the server’s plan?'),
                content: Text(mine
                    ? 'The server plan will be replaced by the plan on this device.'
                    : 'The local plan will be replaced by the server plan. Unsynced local changes will be discarded.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Use this version'))
                ]));
    if (ok == true && mounted) {
      await ref
          .read(tripPlanRepositoryProvider)
          .resolve(widget.tripId, keepMine: mine);
    }
  }

  Widget _daySelector(List<String> days, String selected) => SizedBox(
      height: 88 + (MediaQuery.textScalerOf(context).scale(25) - 25),
      child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          children: [
            for (final day in [...days, ''])
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                      message: day.isEmpty ? 'Unscheduled' : day,
                      child: ChoiceChip(
                          key: ValueKey('day-$day'),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                              color: day == selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                          label:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                day.isEmpty
                                    ? 'ANYTIME'
                                    : DateFormat('EEE')
                                        .format(DateTime.parse(day))
                                        .toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                                day.isEmpty
                                    ? 'Ideas'
                                    : DateFormat('d MMM')
                                        .format(DateTime.parse(day)),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ]),
                          selected: day == selected,
                          onSelected: (_) =>
                              setState(() => selectedDay = day)))),
          ]));

  Widget _overview(Trip trip, TripPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final done = plan.checks.where((c) => c.done).length;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.landscape_outlined, size: 40, color: scheme.primary),
        const SizedBox(height: 20),
        Text('THE BIG PICTURE',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: scheme.primary)),
        const SizedBox(height: 12),
        Text(
            '${tripDates(trip.startDate, trip.endDate).length} days to explore',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.7)),
        const SizedBox(height: 24),
        for (final stat in [
          (Icons.route_outlined, '${plan.entries.length} planned items'),
          (Icons.bookmark_border_rounded, '${plan.places.length} saved places'),
          (
            Icons.task_alt_rounded,
            '$done of ${plan.checks.length} tasks complete'
          ),
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Icon(stat.$1, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(stat.$2,
                        style: Theme.of(context).textTheme.bodyMedium)),
              ])),
        if (trip.notes.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 12),
          Text('TRIP NOTES', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(trip.notes),
        ],
      ]),
    ));
  }

  Widget _itinerary(Trip trip, TripPlan plan, List<String> days, String day) {
    final entries = plan.entries.where((e) => e.date == day).toList();
    final continuing = day.isEmpty
        ? <PlanEntry>[]
        : plan.entries.where((e) => e.date != day && e.occursOn(day)).toList();
    final timeline = Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Your itinerary',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: -.7)),
                  const SizedBox(height: 5),
                  Text(
                      '${DateFormat('d MMM').format(trip.startDate)} – ${DateFormat('d MMM yyyy').format(trip.endDate)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
            FilledButton.icon(
                onPressed: () {
                  selectedDay = day;
                  addOrEdit(trip, plan);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add item'))
          ])),
      if (trip.notes.isNotEmpty && MediaQuery.sizeOf(context).width < 900)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(trip.notes,
                    maxLines: 3, overflow: TextOverflow.ellipsis))),
      _daySelector(days, day),
      if (day.isNotEmpty)
        ListTile(
            dense: true,
            leading: Icon(Icons.edit_note_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: Text(
                plan.dayNotes[day]?.isNotEmpty == true
                    ? plan.dayNotes[day]!
                    : 'Add a note for this day',
                maxLines: 3,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _dayNote(plan, day)),
      Expanded(
          child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        buildDefaultDragHandles: false,
        header: Column(children: [
          for (final e in continuing)
            _entryCard(trip, plan, e, continuing: true),
          if (entries.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Icon(Icons.explore_outlined,
                      size: 40, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(day.isEmpty
                      ? 'Ideas without a date live here.'
                      : 'A day with room to explore.'),
                  const SizedBox(height: 8),
                  const Text('Add an activity, meal, transport or booking.')
                ])),
        ]),
        itemCount: entries.length,
        itemBuilder: (_, index) => _entryCard(trip, plan, entries[index],
            key: ValueKey(entries[index].id), dragIndex: index),
        onReorder: (oldIndex, newIndex) async {
          final before = entries.map((e) => e.id).toList();
          final ids = [...before];
          if (newIndex > oldIndex) newIndex--;
          ids.insert(newIndex, ids.removeAt(oldIndex));
          await change((p) => p.reorder(day, ids));
          if (mounted) undo('Order updated', (p) => p.reorder(day, before));
        },
      )),
    ]);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) return timeline;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: timeline),
        SizedBox(
            width: 300,
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 24, 20, 24),
                child: _overview(trip, plan))),
      ]);
    });
  }

  Future<void> _dayNote(TripPlan plan, String day) async {
    var draft = plan.dayNotes[day] ?? '';
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text('Note · $day'),
                content: TextFormField(
                    initialValue: draft,
                    onChanged: (value) => draft = value,
                    maxLines: 5,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                        hintText: 'Opening hours, a reminder, a backup plan…')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, draft.trim()),
                      child: const Text('Save'))
                ]));
    if (result != null && mounted) {
      await change((p) {
        if (result.isEmpty) {
          p.dayNotes.remove(day);
        } else {
          p.dayNotes[day] = result;
        }
      });
    }
  }

  Widget _entryCard(Trip trip, TripPlan plan, PlanEntry e,
      {Key? key, int? dragIndex, bool continuing = false}) {
    final place = plan.place(e.placeId);
    final linked =
        trip.expenses.where((x) => x.plannerEntryId == e.id).toList();
    final currency = ref.watch(displayCurrencyProvider);
    final total =
        linked.fold<double>(0, (sum, x) => sum + x.displayAmount(currency));
    final subtitle = [
      if (continuing) 'Continues from ${e.date}',
      if (e.timezone.isNotEmpty) 'Time zone · ${e.timezone}',
      if (e.endDate.isNotEmpty || e.endTime.isNotEmpty)
        'Until ${e.endDate.isEmpty ? e.date : e.endDate} ${e.endTime}${e.endTimezone.isEmpty ? '' : ' ${e.endTimezone}'}',
      if (place != null)
        '${place.title}${place.address.isEmpty ? '' : ' · ${place.address}'}'
    ];
    return Card(
        key: key,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                TravelKindIcon(e.kind),
                const SizedBox(width: 12),
                Expanded(
                    child: InkWell(
                        onTap: () => addOrEdit(trip, plan, entry: e),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  [
                                    if (e.time.isNotEmpty) e.time,
                                    PlanEntry.kinds[e.kind]!,
                                    if (e.isBooking) e.status
                                  ].join(' · '),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              Text(e.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -.2))
                            ]))),
                if (dragIndex != null)
                  ReorderableDragStartListener(
                      index: dragIndex,
                      child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Tooltip(
                              message: 'Drag to reorder',
                              child: Icon(Icons.drag_indicator_rounded,
                                  size: 18,
                                  color:
                                      Theme.of(context).colorScheme.outline)))),
                PopupMenuButton<String>(
                    tooltip: 'Item actions',
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await addOrEdit(trip, plan, entry: e);
                        return;
                      }
                      if (action == 'move') {
                        await _moveEntry(trip, plan, e);
                        return;
                      }
                      if (action == 'delete') {
                        final ok = await showDeleteConfirmDialog(context,
                            title: 'Remove item',
                            content:
                                'Remove "${e.title}" from your plan? Existing expenses will be kept.');
                        if (ok && mounted) {
                          await change((p) =>
                              p.entries.removeWhere((x) => x.id == e.id));
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'move',
                              child: Text('Move to another day')),
                          PopupMenuItem(value: 'delete', child: Text('Remove'))
                        ]),
              ]),
              if (subtitle.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(subtitle.join('\n'),
                        style: Theme.of(context).textTheme.bodySmall)),
              if (e.notes.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(e.notes)),
              if (e.confirmation.isNotEmpty)
                Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Expanded(
                          child: SelectableText(
                              'Confirmation: ${e.confirmation}')),
                      IconButton(
                          tooltip: 'Copy confirmation',
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => Clipboard.setData(
                              ClipboardData(text: e.confirmation)))
                    ])),
              Wrap(spacing: 4, children: [
                if (place != null)
                  TextButton.icon(
                      onPressed: () => navigateToPlace(context, place),
                      icon: const Icon(Icons.near_me_outlined, size: 16),
                      label: const Text('Navigate')),
                if (e.url.isNotEmpty)
                  TextButton.icon(
                      onPressed: () => openPlanLink(context, e.url),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open link')),
                TextButton.icon(
                    onPressed: () => expense(trip, entry: e),
                    icon: const Icon(Icons.add_card, size: 16),
                    label: Text(linked.isEmpty
                        ? 'Add expense'
                        : '${CurrencyUtils.format(total, currency)} · Add expense')),
              ]),
            ])));
  }

  Future<void> _moveEntry(Trip trip, TripPlan plan, PlanEntry e) async {
    final day = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (_) => ListView(shrinkWrap: true, children: [
              const ListTile(title: Text('Move to…')),
              for (final day in [...daysFor(trip, plan), ''])
                ListTile(
                    title: Text(day.isEmpty ? 'Unscheduled' : day),
                    selected: day == e.date,
                    onTap: () => Navigator.pop(context, day))
            ]));
    if (day != null && mounted) {
      await change((p) {
        final current = p.entry(e.id);
        if (current != null) p.saveEntry(current.movedTo(day));
      });
      if (mounted) {
        undo('Item moved', (p) {
          final current = p.entry(e.id);
          if (current != null) {
            p.saveEntry(PlanEntry.fromJson(
                {...current.toJson(), 'date': e.date, 'end_date': e.endDate}));
          }
        });
      }
    }
  }

  Widget _places(Trip trip, TripPlan plan) {
    final places = plan.places
        .where((p) =>
            '${p.title} ${p.address}'
                .toLowerCase()
                .contains(query.toLowerCase()) &&
            (!unplannedOnly || !plan.entries.any((e) => e.placeId == p.id)))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                decoration: const InputDecoration(
                    hintText: 'Search your saved places',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => query = v)),
            const SizedBox(height: 10),
            Row(children: [
              FilterChip(
                  label: const Text('Not yet planned'),
                  selected: unplannedOnly,
                  onSelected: (v) => setState(() => unplannedOnly = v)),
              const Spacer(),
              FilledButton.icon(
                  onPressed: () => placeEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Place'))
            ])
          ])),
      Expanded(
          child: places.isEmpty
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          plan.places.isEmpty
                              ? 'Save places you want to visit, then add them to a day.\nYou can also long-press the map to save a pin.'
                              : 'No matching places.',
                          textAlign: TextAlign.center)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: places.length,
                  itemBuilder: (_, i) {
                    final place = places[i];
                    final count =
                        plan.entries.where((e) => e.placeId == place.id).length;
                    return Card(
                        child: ListTile(
                            leading: const TravelKindIcon('activity'),
                            title: Text(place.title),
                            subtitle: Text([
                              if (place.address.isNotEmpty) place.address,
                              count == 0
                                  ? 'Not yet planned'
                                  : 'In $count itinerary items'
                            ].join('\n')),
                            isThreeLine: place.address.isNotEmpty,
                            trailing: IconButton(
                                tooltip: 'Add to a day',
                                icon: const Icon(Icons.playlist_add),
                                onPressed: () =>
                                    addOrEdit(trip, plan, place: place)),
                            onTap: () => _placeActions(trip, plan, place)));
                  })),
    ]);
  }

  Future<void> _placeActions(Trip trip, TripPlan plan, PlanPlace place) async {
    final action = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (_) => SafeArea(
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: Text(place.title),
                  subtitle: Text([place.address, place.notes]
                      .where((s) => s.isNotEmpty)
                      .join('\n'))),
              ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Add to a day'),
                  onTap: () => Navigator.pop(context, 'schedule')),
              ListTile(
                  leading: const Icon(Icons.near_me_outlined),
                  title: const Text('Navigate'),
                  onTap: () => Navigator.pop(context, 'navigate')),
              if (place.url.isNotEmpty)
                ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Open saved link'),
                    onTap: () => Navigator.pop(context, 'link')),
              ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit place'),
                  onTap: () => Navigator.pop(context, 'edit')),
              ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove place'),
                  onTap: () => Navigator.pop(context, 'delete')),
            ]))));
    if (!mounted) return;
    switch (action) {
      case 'schedule':
        await addOrEdit(trip, plan, place: place);
      case 'navigate':
        await navigateToPlace(context, place);
      case 'link':
        await openPlanLink(context, place.url);
      case 'edit':
        await placeEditor(place: place);
      case 'delete':
        final ok = await showDeleteConfirmDialog(context,
            title: 'Remove place',
            content:
                'Remove "${place.title}"? Scheduled activities will remain, without the place link.');
        if (ok && mounted) await change((p) => p.removePlace(place.id));
    }
  }

  Future<void> _checkEditor({PlanCheck? check, String kind = 'packing'}) async {
    final result = await editCheck(context, check: check, kind: kind);
    if (result != null && mounted) await change((p) => p.saveCheck(result));
  }

  Widget _lists(TripPlan plan) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        for (final kind in ['packing', 'todo']) ...[
          Row(children: [
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TravelKindIcon(kind == 'packing' ? 'hotel' : 'note')),
            Expanded(
                child: Text(kind == 'packing' ? 'Packing list' : 'To-dos',
                    style: Theme.of(context).textTheme.titleLarge)),
            Text(
                '${plan.checks.where((c) => c.kind == kind && c.done).length}/${plan.checks.where((c) => c.kind == kind).length}'),
            IconButton(
                tooltip: 'Add ${kind == 'packing' ? 'packing item' : 'to-do'}',
                onPressed: () => _checkEditor(kind: kind),
                icon: const Icon(Icons.add))
          ]),
          if (kind == 'packing' && !plan.checks.any((c) => c.kind == kind))
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: () => change((p) {
                          for (final title in [
                            'Passport / ID',
                            'Wallet & cards',
                            'Phone charger',
                            'Travel adapter',
                            'Medication',
                            'Clothes',
                            'Toiletries'
                          ]) {
                            if (!p.checks.any((c) =>
                                c.kind == 'packing' && c.title == title)) {
                              p.saveCheck(
                                  PlanCheck(id: newTravelId(), title: title));
                            }
                          }
                        }),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Start with travel essentials'))),
          for (final check in plan.checks.where((c) => c.kind == kind))
            Card(
                child: Row(children: [
              Checkbox(
                  value: check.done,
                  onChanged: (done) => change((p) {
                        final current =
                            p.checks.where((c) => c.id == check.id).firstOrNull;
                        if (current != null) {
                          p.saveCheck(PlanCheck.fromJson(
                              {...current.toJson(), 'done': done}));
                        }
                      })),
              Expanded(
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(check.title,
                          style: TextStyle(
                              decoration: check.done
                                  ? TextDecoration.lineThrough
                                  : null)),
                      subtitle: (check.due.isEmpty && check.notes.isEmpty)
                          ? null
                          : Text([
                              if (check.due.isNotEmpty) 'Due ${check.due}',
                              if (check.notes.isNotEmpty) check.notes
                            ].join('\n')),
                      onTap: () => _checkEditor(check: check, kind: kind))),
              IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await change(
                        (p) => p.checks.removeWhere((c) => c.id == check.id));
                    if (mounted) {
                      undo('Item removed', (p) => p.saveCheck(check));
                    }
                  })
            ])),
          if (kind == 'todo' && !plan.checks.any((c) => c.kind == kind))
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'Remember tickets, reservations and things to do before you leave.')),
          const SizedBox(height: 24),
        ],
      ]);

  Widget _expenses(Trip trip, TripPlan plan) {
    final currency = ref.watch(displayCurrencyProvider);
    final categories = <String, double>{};
    for (final e in trip.expenses) {
      categories.update(e.category, (v) => v + e.displayAmount(currency),
          ifAbsent: () => e.displayAmount(currency));
    }
    final total = categories.values.fold<double>(0, (a, b) => a + b);
    return Column(children: [
      Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Total spent',
                      style: Theme.of(context).textTheme.labelMedium),
                  Text(CurrencyUtils.format(total, currency),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700, letterSpacing: -1))
                ])),
            FilledButton.icon(
                onPressed: () => expense(trip),
                icon: const Icon(Icons.add),
                label: const Text('Expense'))
          ])),
      if (categories.isNotEmpty)
        SizedBox(
            height: 44,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: categories.entries
                    .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                            label: Text(
                                '${e.key}: ${CurrencyUtils.format(e.value, currency)}'))))
                    .toList())),
      Expanded(
          child: trip.expenses.isEmpty
              ? const Center(child: Text('No expenses yet'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: trip.expenses.length,
                  itemBuilder: (_, i) {
                    final e = trip.expenses[i];
                    final linked = plan.entry(e.plannerEntryId);
                    return Card(
                        child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: TravelKindIcon(e.category),
                            onTap: () => expense(trip, expense: e),
                            title: Text(e.name),
                            subtitle: Text(
                                '${planDate(e.date)} · ${e.category}${linked == null ? '' : '\n${linked.title}'}'),
                            trailing: AmountDisplay(
                                amount: e.displayAmount(currency),
                                currency: currency,
                                originalAmount: e.amount,
                                originalCurrency: e.currency)));
                  })),
    ]);
  }
}
