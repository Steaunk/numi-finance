import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import 'plan_links.dart';

Future<PlanItem?> editPlanItem(
        BuildContext context, Trip trip, TripPlan plan, PlanItem item) =>
    showModalBottomSheet<PlanItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PlanItemEditor(trip: trip, plan: plan, item: item));

class PlanItemEditor extends StatefulWidget {
  final Trip trip;
  final TripPlan plan;
  final PlanItem item;
  const PlanItemEditor(
      {super.key, required this.trip, required this.plan, required this.item});
  @override
  State<PlanItemEditor> createState() => _PlanItemEditorState();
}

class _PlanItemEditorState extends State<PlanItemEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  late Map<String, String> values;
  late List<PlanLink> links;
  String? error;
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.item.fields);
    links = widget.item.links.toList();
    for (final key in [
      'title',
      'address',
      'endAddress',
      'notes',
      'confirmation',
      'contact',
      'assignee',
      'timezone',
      'endTimezone'
    ]) {
      _controllers[key] = TextEditingController(text: widget.item[key]);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get kind => widget.item.kind;
  bool get stay => kind == 'booking' && values['category'] == 'Accommodation';
  bool get noStay =>
      kind == 'booking' && values['category'] == 'No accommodation needed';
  Widget text(String key, String label,
          {bool required = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: _controllers[key],
              maxLines: lines,
              maxLength: key == 'notes' ? 10000 : 500,
              decoration: InputDecoration(labelText: label, counterText: ''),
              validator: (v) => required && (v == null || v.trim().isEmpty)
                  ? 'Required'
                  : null));
  Widget choice(String key, String label, List<String> options) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
          key: ValueKey('$key-${values[key]}'),
          isExpanded: true,
          initialValue:
              options.contains(values[key]) ? values[key] : options.first,
          decoration: InputDecoration(labelText: label),
          items: options
              .map((v) => DropdownMenuItem(
                  value: v, child: Text(v, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => values[key] = v!)));
  Widget dateField(String key, String label, {bool required = false}) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(values[key]?.isNotEmpty == true
              ? values[key]!
              : required
                  ? 'Choose date'
                  : 'Not set'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (values[key]?.isNotEmpty == true)
              IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => values[key] = '')),
            const Icon(Icons.calendar_today_outlined, size: 20)
          ]),
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(values[key] ?? '') ??
                    widget.trip.startDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200));
            if (picked != null) setState(() => values[key] = planDate(picked));
          });
  Widget timeField(String key, String label) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle:
          Text(values[key]?.isNotEmpty == true ? values[key]! : 'Flexible'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (values[key]?.isNotEmpty == true)
          IconButton(
              tooltip: 'Clear $label',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => values[key] = '')),
        const Icon(Icons.schedule, size: 20)
      ]),
      onTap: () async {
        final parts = (values[key] ?? '').split(':');
        final initial = parts.length == 2
            ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
            : const TimeOfDay(hour: 9, minute: 0);
        final picked =
            await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          setState(() => values[key] =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      });
  void save() {
    if (!_form.currentState!.validate()) return;
    final updated = {
      ...values,
      for (final e in _controllers.entries) e.key: e.value.text.trim()
    };
    if (kind == 'activity' && updated['placeId']?.isNotEmpty == true) {
      // Title overrides are allowed; address and links remain on the linked place.
      updated['address'] = '';
    }
    String? problem;
    if (kind == 'booking' && (updated['date'] ?? '').isEmpty) {
      problem = 'Choose a booking date.';
    }
    if (stay &&
        ((updated['endDate'] ?? '').isEmpty ||
            updated['endDate']!.compareTo(updated['date'] ?? '') <= 0)) {
      problem = 'Checkout must be after check-in.';
    }
    if (kind == 'activity' &&
        (updated['date'] ?? '').isNotEmpty &&
        (updated['date']!.compareTo(planDate(widget.trip.startDate)) < 0 ||
            updated['date']!.compareTo(planDate(widget.trip.endDate)) > 0)) {
      problem =
          'Choose a date within this trip, or clear the date to leave it unassigned.';
    }
    if (links.length > 50) problem = 'Keep at most 50 links per item.';
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    Navigator.pop(context, PlanItem(updated, links: links));
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.plan.ofKind('place');
    final linked = (values['placeId'] ?? '').isNotEmpty;
    return SafeArea(
        child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
                child: Form(
                    key: _form,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    'Edit ${kind == 'task' ? 'checklist item' : kind}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: 'Close editor',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          const SizedBox(height: 12),
                          text(
                              'title',
                              linked
                                  ? 'Activity name (optional override)'
                                  : 'Name',
                              required: !linked),
                          if (kind == 'place') ...[
                            choice('category', 'Category', placeCategories),
                            choice('priority', 'Priority', planPriorities)
                          ],
                          if (kind == 'booking')
                            choice(
                                'category', 'Booking type', bookingCategories),
                          if (kind == 'task')
                            choice('category', 'Checklist', taskCategories),
                          choice(
                              'status',
                              'Status',
                              kind == 'task'
                                  ? ['todo', 'completed']
                                  : planStatuses),
                          if (kind == 'activity') ...[
                            DropdownButtonFormField<String>(
                                initialValue: values['placeId'] ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Saved place'),
                                items: [
                                  const DropdownMenuItem(
                                      value: '',
                                      child: Text('No linked place')),
                                  ...places.map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.title,
                                          overflow: TextOverflow.ellipsis)))
                                ],
                                onChanged: (v) =>
                                    setState(() => values['placeId'] = v!)),
                            dateField('date', 'Day'),
                            timeField('time', 'Time'),
                            timeField('endTime', 'End time'),
                          ],
                          if (kind == 'booking') ...[
                            dateField(
                                'date',
                                stay
                                    ? 'Check-in date'
                                    : noStay
                                        ? 'Night'
                                        : 'Start date',
                                required: true),
                            if (!noStay) ...[
                              timeField(
                                  'time',
                                  stay
                                      ? 'Check-in time'
                                      : 'Departure / start time'),
                              text('timezone',
                                  'Start time zone (e.g. Asia/Tokyo)'),
                              dateField(
                                  'endDate',
                                  stay
                                      ? 'Check-out date'
                                      : 'Arrival / end date',
                                  required: stay),
                              timeField(
                                  'endTime',
                                  stay
                                      ? 'Check-out time'
                                      : 'Arrival / end time'),
                              if (!stay)
                                text('endTimezone',
                                    'Arrival time zone (e.g. America/Los_Angeles)'),
                              const Text(
                                  'Times are local to the stated time zone. No automatic time conversion.',
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (kind != 'task' && !linked && !noStay)
                            text(
                                'address',
                                kind == 'booking' && !stay
                                    ? 'Departure / start address'
                                    : 'Address'),
                          if (kind == 'booking' && !stay && !noStay)
                            text('endAddress', 'Arrival / end address'),
                          if (kind == 'booking' && !noStay) ...[
                            text('confirmation',
                                'Confirmation / flight / train number'),
                            text('contact', 'Contact'),
                            dateField('cancelBy', 'Cancellation deadline')
                          ],
                          if (kind == 'task') ...[
                            dateField('date', 'Due date'),
                            text('assignee', 'Responsible person')
                          ],
                          text(
                              'notes',
                              kind == 'place'
                                  ? 'Why go, opening hours, duration, things to try'
                                  : 'Notes',
                              lines: 3),
                          if (kind != 'task')
                            PlanLinksEditor(
                                links: links,
                                onChanged: (v) => setState(() => links = v)),
                          if (error != null)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                              onPressed: save,
                              icon: const Icon(Icons.check),
                              label: const Text('Save item')),
                        ]))),
              ),
            )));
  }
}
