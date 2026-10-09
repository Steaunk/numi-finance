import 'package:flutter/material.dart';
import '../../../models/trip_plan.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _timezonesLoaded = false;
String? _timezone(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (!_timezonesLoaded) {
    tz_data.initializeTimeZones();
    _timezonesLoaded = true;
  }
  try {
    tz.getLocation(value.trim());
    return null;
  } catch (_) {
    return 'Use a timezone such as Asia/Tokyo';
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;
String? _url(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty
      ? null
      : 'Enter an http or https link';
}

String? _time(String? value) {
  if (value == null || value.isEmpty) return null;
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)
      ? null
      : 'Use HH:mm';
}

Future<T?> _editor<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => child);
Future<PlanPlace?> editPlace(BuildContext context,
        {PlanPlace? place, double? lat, double? lng}) =>
    _editor(context, _PlaceEditor(place: place, lat: lat, lng: lng));
Future<PlanEntry?> editEntry(BuildContext context,
        {required TripPlan plan,
        required List<String> days,
        PlanEntry? entry,
        String date = '',
        PlanPlace? place}) =>
    _editor(
        context,
        _EntryEditor(
            plan: plan, days: days, entry: entry, date: date, place: place));
Future<PlanCheck?> editCheck(BuildContext context,
        {PlanCheck? check, String kind = 'packing'}) =>
    _editor(context, _CheckEditor(check: check, kind: kind));

class _EditorFrame extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback save;
  const _EditorFrame(
      {required this.title,
      required this.formKey,
      required this.children,
      required this.save});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
            child: Form(
                key: formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(title,
                                style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ]),
                      for (final child in children) ...[
                        const SizedBox(height: 12),
                        child
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) save();
                          },
                          child: const Text('Save')),
                    ]))),
      );
}

class _PlaceEditor extends StatefulWidget {
  final PlanPlace? place;
  final double? lat, lng;
  const _PlaceEditor({this.place, this.lat, this.lng});
  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  final _key = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.place?.title);
  late final address = TextEditingController(text: widget.place?.address);
  late final notes = TextEditingController(text: widget.place?.notes);
  late final url = TextEditingController(text: widget.place?.url);
  late final lat = TextEditingController(
      text: (widget.place?.lat ?? widget.lat)?.toString() ?? '');
  late final lng = TextEditingController(
      text: (widget.place?.lng ?? widget.lng)?.toString() ?? '');
  @override
  void dispose() {
    for (final c in [title, address, notes, url, lat, lng]) {
      c.dispose();
    }
    super.dispose();
  }

  String? coord(String? value, double max, String other) {
    if ((value?.trim().isEmpty ?? true) && other.trim().isEmpty) return null;
    final v = double.tryParse(value?.trim() ?? '');
    return v == null || !v.isFinite || v.abs() > max
        ? 'Enter a valid coordinate'
        : null;
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
          title: widget.place == null ? 'Save a place' : 'Edit place',
          formKey: _key,
          save: () => Navigator.pop(
              context,
              PlanPlace(
                  id: widget.place?.id ?? newTravelId(),
                  title: title.text.trim(),
                  address: address.text.trim(),
                  notes: notes.text.trim(),
                  url: url.text.trim(),
                  lat: double.tryParse(lat.text.trim()),
                  lng: double.tryParse(lng.text.trim()))),
          children: [
            TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Place name'),
                maxLength: 200,
                validator: _required),
            TextFormField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLength: 500),
            TextFormField(
                controller: url,
                decoration:
                    const InputDecoration(labelText: 'Website or map link'),
                keyboardType: TextInputType.url,
                validator: _url,
                maxLength: 2000),
            Text(
                'Optional coordinates place a pin on the map. You can also long-press the map to add a place.',
                style: Theme.of(context).textTheme.bodySmall),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextFormField(
                      controller: lat,
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) => coord(v, 90, lng.text))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: lng,
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) => coord(v, 180, lat.text)))
            ]),
            TextFormField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                maxLength: 5000),
          ]);
}

class _EntryEditor extends StatefulWidget {
  final TripPlan plan;
  final List<String> days;
  final PlanEntry? entry;
  final PlanPlace? place;
  final String date;
  const _EntryEditor(
      {required this.plan,
      required this.days,
      this.entry,
      this.place,
      required this.date});
  @override
  State<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<_EntryEditor> {
  final _key = GlobalKey<FormState>();
  late final title =
      TextEditingController(text: widget.entry?.title ?? widget.place?.title);
  late final time = TextEditingController(text: widget.entry?.time);
  late final endTime = TextEditingController(text: widget.entry?.endTime);
  late final notes = TextEditingController(text: widget.entry?.notes);
  late final confirmation =
      TextEditingController(text: widget.entry?.confirmation);
  late final timezone = TextEditingController(text: widget.entry?.timezone);
  late final endTimezone =
      TextEditingController(text: widget.entry?.endTimezone);
  late final url = TextEditingController(text: widget.entry?.url);
  late String kind = widget.entry?.kind ?? 'activity';
  late String day = widget.entry?.date ?? widget.date;
  late String endDay = widget.entry?.endDate ?? '';
  late String placeId = widget.entry?.placeId ?? widget.place?.id ?? '';
  late String status = widget.entry?.status ?? 'pending';
  bool get booking => ['hotel', 'flight', 'train', 'booking'].contains(kind);
  List<String> get days => {
        ...widget.days,
        if (day.isNotEmpty) day,
        if (endDay.isNotEmpty) endDay
      }.toList()
        ..sort();
  @override
  void dispose() {
    for (final c in [
      title,
      time,
      endTime,
      notes,
      confirmation,
      timezone,
      endTimezone,
      url
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickDay(bool end) async {
    final seed = (end ? endDay : day);
    final selected = await showDatePicker(
        context: context,
        initialDate: DateTime.parse(seed.isEmpty ? widget.days.first : seed),
        firstDate: DateTime(1900),
        lastDate: DateTime(2200));
    if (selected != null && mounted) {
      setState(() {
        if (end) {
          endDay = planDate(selected);
        } else {
          day = planDate(selected);
        }
      });
    }
  }

  void save() {
    if (endDay.isNotEmpty && (day.isEmpty || endDay.compareTo(day) < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End date must be on or after the start date.')));
      return;
    }
    if (endDay.isNotEmpty &&
        DateTime.parse(endDay).difference(DateTime.parse(day)).inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A booking can span at most 366 days.')));
      return;
    }
    if (time.text.isNotEmpty &&
        endTime.text.isNotEmpty &&
        (endDay.isEmpty || endDay == day) &&
        timezone.text.trim() == endTimezone.text.trim() &&
        endTime.text.compareTo(time.text) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'End time must follow the start time, or choose another end date.')));
      return;
    }
    Navigator.pop(
        context,
        PlanEntry(
            id: widget.entry?.id ?? newTravelId(),
            title: title.text.trim(),
            kind: kind,
            date: day,
            time: time.text.trim(),
            endDate: endDay,
            endTime: endTime.text.trim(),
            placeId: placeId,
            notes: notes.text.trim(),
            status: status,
            confirmation: confirmation.text.trim(),
            timezone: timezone.text.trim(),
            endTimezone: endTimezone.text.trim(),
            url: url.text.trim()));
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
          title: widget.entry == null ? 'Add to your trip' : 'Edit trip item',
          formKey: _key,
          save: save,
          children: [
            TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLength: 200,
                validator: _required),
            DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: PlanEntry.kinds.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => kind = v!)),
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                      key: ValueKey('day:$day'),
                      initialValue: day,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('Unscheduled')),
                        ...days.map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)))
                      ],
                      onChanged: (v) => setState(() => day = v!))),
              IconButton(
                  tooltip: 'Choose another date',
                  onPressed: () => pickDay(false),
                  icon: const Icon(Icons.calendar_month))
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextFormField(
                      controller: time,
                      decoration: const InputDecoration(
                          labelText: 'Start time (HH:mm)'),
                      validator: _time,
                      keyboardType: TextInputType.datetime)),
              const SizedBox(width: 12),
              Expanded(
                  child: TextFormField(
                      controller: endTime,
                      decoration:
                          const InputDecoration(labelText: 'End time (HH:mm)'),
                      validator: _time,
                      keyboardType: TextInputType.datetime))
            ]),
            if (booking) ...[
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        key: ValueKey('end:$endDay'),
                        initialValue: endDay,
                        decoration: const InputDecoration(
                            labelText: 'End / check-out day'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Same day')),
                          ...days.map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                        ],
                        onChanged: (v) => setState(() => endDay = v!))),
                IconButton(
                    tooltip: 'Choose end date',
                    onPressed: () => pickDay(true),
                    icon: const Icon(Icons.calendar_month))
              ]),
              DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration:
                      const InputDecoration(labelText: 'Booking status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled'))
                  ],
                  onChanged: (v) => setState(() => status = v!)),
              TextFormField(
                  controller: confirmation,
                  decoration:
                      const InputDecoration(labelText: 'Confirmation number'),
                  maxLength: 100),
              TextFormField(
                  controller: timezone,
                  validator: _timezone,
                  decoration: const InputDecoration(
                      labelText: 'Start timezone (optional)',
                      hintText: 'Asia/Shanghai'),
                  maxLength: 100),
              if (kind == 'flight' || kind == 'train')
                TextFormField(
                    controller: endTimezone,
                    validator: _timezone,
                    decoration: const InputDecoration(
                        labelText: 'Arrival timezone (optional)',
                        hintText: 'Asia/Tokyo'),
                    maxLength: 100),
            ],
            DropdownButtonFormField<String>(
                initialValue: widget.plan.place(placeId) == null ? '' : placeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Saved place'),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('No linked place')),
                  ...widget.plan.places.map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.title, overflow: TextOverflow.ellipsis)))
                ],
                onChanged: (v) => placeId = v!),
            TextFormField(
                controller: url,
                decoration:
                    const InputDecoration(labelText: 'Booking or website link'),
                keyboardType: TextInputType.url,
                validator: _url,
                maxLength: 2000),
            TextFormField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
                maxLength: 5000),
          ]);
}

class _CheckEditor extends StatefulWidget {
  final PlanCheck? check;
  final String kind;
  const _CheckEditor({this.check, required this.kind});
  @override
  State<_CheckEditor> createState() => _CheckEditorState();
}

class _CheckEditorState extends State<_CheckEditor> {
  final _key = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.check?.title);
  late final notes = TextEditingController(text: widget.check?.notes);
  late String due = widget.check?.due ?? '';
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorFrame(
          title: widget.kind == 'packing' ? 'Packing item' : 'To-do',
          formKey: _key,
          save: () => Navigator.pop(
              context,
              PlanCheck(
                  id: widget.check?.id ?? newTravelId(),
                  title: title.text.trim(),
                  kind: widget.kind,
                  notes: notes.text.trim(),
                  due: due,
                  done: widget.check?.done ?? false)),
          children: [
            TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Item'),
                maxLength: 200,
                validator: _required),
            if (widget.kind == 'todo')
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(due.isEmpty ? 'No due date' : due),
                  trailing: due.isEmpty
                      ? const Icon(Icons.calendar_month)
                      : IconButton(
                          tooltip: 'Clear due date',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => due = '')),
                  onTap: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate:
                            due.isEmpty ? DateTime.now() : DateTime.parse(due),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200));
                    if (date != null && mounted) {
                      setState(() => due = planDate(date));
                    }
                  }),
            TextFormField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
                maxLength: 5000),
          ]);
}
