import 'package:flutter/material.dart';
import '../../../config/constants.dart';
import '../../common/widgets/dialogs.dart';
import '../../../models/trip.dart';
import '../../../models/trip_plan.dart';
import 'plan_links.dart';
import 'travel_surfaces.dart';

Future<PlanItem?> editPlanItem(
        BuildContext context, Trip trip, TripPlan plan, PlanItem item) =>
    showModalBottomSheet<PlanItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        constraints: const BoxConstraints(maxWidth: 680),
        backgroundColor: travelSurface(context),
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
  late List<String> participants;
  late bool everyone;
  String? error;
  @override
  void initState() {
    super.initState();
    values = Map.of(widget.item.fields);
    links = widget.item.links.toList();
    participants = widget.item.participantIds.toList();
    everyone = participants.isEmpty;
    if (payable) {
      values.putIfAbsent('currency', () => AppConstants.defaultCurrency);
      values.putIfAbsent('paymentStatus', () => 'unpaid');
      values.putIfAbsent('paidDate', () => planDate(DateTime.now()));
      values.putIfAbsent(
          'expenseCategory',
          () => planExpenseCategory(
              widget.plan.find(widget.item['placeId'])?['category'] ??
                  widget.item['category']));
    }
    for (final key in [
      'title',
      'address',
      'endAddress',
      'notes',
      'confirmation',
      'contact',
      'assignee',
      'timezone',
      'endTimezone',
      'amount'
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
  bool get payable => kind == 'booking' || kind == 'activity';
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
          onChanged: (v) => setState(() {
                values[key] = v!;
                if (kind == 'booking' && key == 'category') {
                  values['expenseCategory'] = planExpenseCategory(v);
                }
              })));
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
            if (picked != null && mounted) {
              setState(() => values[key] = planDate(picked));
            }
          });
  Widget destinationChoice(String key, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$key-${values[key]}'),
        initialValue: widget.plan.destinations.any((d) => d.id == values[key])
            ? values[key]
            : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: '', child: Text('Unassigned')),
          ...widget.plan.destinations.map((d) => DropdownMenuItem(
              value: d.id,
              child: Text(d.title, overflow: TextOverflow.ellipsis)))
        ],
        onChanged: (v) => setState(() => values[key] = v!),
      ));
  bool get transport =>
      kind == 'booking' &&
      ['Flight', 'Train', 'Bus', 'Car rental'].contains(values['category']);
  Widget stayDurationField({bool destination = false}) {
    final item = widget.item.copy(values);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(destination ? 'Visit dates' : 'Stay duration'),
      subtitle: Text(destination
          ? (values['date']?.isNotEmpty == true &&
                  values['endDate']?.isNotEmpty == true
              ? '${values['date']} – ${values['endDate']}'
              : 'Choose arrival and departure dates')
          : item.stayNights == null
              ? 'Choose check-in and check-out dates'
              : 'Check-in ${values['date']}\nCheck-out ${values['endDate']} · ${item.stayDuration}'),
      isThreeLine: !destination && item.stayNights != null,
      trailing: const Icon(Icons.date_range_outlined),
      onTap: () async {
        final start =
            DateTime.tryParse(values['date'] ?? '') ?? widget.trip.startDate;
        final end = DateTime.tryParse(values['endDate'] ?? '');
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDateRange: DateTimeRange(
              start: start,
              end: end != null && !end.isBefore(start)
                  ? end
                  : destination
                      ? start
                      : start.add(const Duration(days: 1))),
          helpText: destination
              ? 'Select arrival and departure'
              : 'Select check-in and check-out',
          fieldStartLabelText: destination ? 'Arrival date' : 'Check-in date',
          fieldEndLabelText: destination ? 'Departure date' : 'Check-out date',
          saveText: 'Use dates',
        );
        if (range != null && mounted) {
          setState(() {
            values['date'] = planDate(range.start);
            values['endDate'] = planDate(range.end);
          });
        }
      },
    );
  }

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
        if (picked != null && mounted) {
          setState(() => values[key] =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      });
  Future<void> save() async {
    if (!_form.currentState!.validate()) return;
    final updated = {
      ...values,
      for (final e in _controllers.entries) e.key: e.value.text.trim()
    };
    if (kind == 'activity' && updated['placeId']?.isNotEmpty == true) {
      // Title overrides are allowed; address and links remain on the linked place.
      updated['address'] = '';
      updated['destinationId'] = '';
    }
    if (!transport) updated['endDestinationId'] = '';
    String? problem;
    if (payable && !everyone && participants.isEmpty) {
      problem = 'Select at least one person, or Everyone.';
    }
    if (kind == 'destination' &&
        ((updated['date'] ?? '').isEmpty ||
            (updated['endDate'] ?? '').isEmpty ||
            updated['endDate']!.compareTo(updated['date']!) < 0)) {
      problem = 'Choose arrival and departure dates in order.';
    }
    if (kind == 'destination' &&
        problem == null &&
        (updated['date']!.compareTo(planDate(widget.trip.startDate)) < 0 ||
            updated['endDate']!.compareTo(planDate(widget.trip.endDate)) > 0)) {
      problem = 'Destination dates must be within the trip dates.';
    }
    if ((stay || noStay) && (updated['date'] ?? '').isEmpty) {
      problem = 'Choose a booking date.';
    }
    if (kind == 'booking' &&
        !stay &&
        !noStay &&
        (updated['date'] ?? '').isEmpty) {
      updated['endDate'] = '';
      updated['time'] = '';
      updated['endTime'] = '';
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
    if (payable) {
      if (noStay) updated['paymentStatus'] = 'unpaid';
      final amount = double.tryParse(updated['amount'] ?? '');
      if ((updated['amount'] ?? '').isNotEmpty &&
          (amount == null || !amount.isFinite || amount <= 0)) {
        problem = 'Enter a positive amount.';
      }
      if (updated['paymentStatus'] == 'paid') {
        if (amount == null || (updated['paidDate'] ?? '').isEmpty) {
          problem = 'Paid items need an amount and payment date.';
        }
        updated['expenseClientId'] = widget.item['expenseClientId'].isEmpty
            ? newPlanId()
            : widget.item['expenseClientId'];
      }
    }
    if (links.length > 50) problem = 'Keep at most 50 links per item.';
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    if (widget.item['paymentStatus'] == 'paid' &&
        updated['paymentStatus'] != 'paid') {
      final confirmed = await showDeleteConfirmDialog(context,
          title: 'Remove recorded payment?',
          content:
              'This removes the linked expense and marks the item unpaid. The itinerary item will be kept.');
      if (!confirmed || !mounted) return;
    }
    Navigator.pop(
        context,
        PlanItem(updated,
            links: links, participantIds: everyone ? [] : participants));
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.plan.ofKind('place');
    final linked = (values['placeId'] ?? '').isNotEmpty;
    final existing = widget.plan.find(widget.item.id) != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
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
                          '${existing ? 'Edit' : 'New'} ${kind == 'task' ? 'checklist item' : kind}',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.5))),
                  IconButton(
                      tooltip: 'Close editor',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ]),
                const SizedBox(height: 20),
                text('title',
                    linked ? 'Activity name (optional override)' : 'Name',
                    required: !linked),
                if (kind == 'place')
                  choice('category', 'Category', placeCategories),
                if (kind == 'booking')
                  choice('category', 'Booking type', bookingCategories),
                if (kind == 'task')
                  choice('category', 'Checklist', taskCategories),
                if (kind == 'destination') stayDurationField(destination: true),
                if (['place', 'activity', 'booking'].contains(kind) &&
                    !linked &&
                    widget.plan.destinations.isNotEmpty)
                  destinationChoice('destinationId',
                      transport ? 'From destination' : 'Destination'),
                if (transport && widget.plan.destinations.isNotEmpty)
                  destinationChoice('endDestinationId', 'To destination'),
                if (linked &&
                    widget.plan
                        .destinationLabel(widget.item.copy(values))
                        .isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Destination: ${widget.plan.destinationLabel(widget.item.copy(values))} · from saved place')),
                if (payable) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Everyone'),
                    subtitle: const Text(
                        'Participants · includes people added later'),
                    value: everyone,
                    onChanged: (v) => setState(() => everyone = v),
                  ),
                  if (!everyone) ...[
                    if (widget.plan.people.isEmpty)
                      const Text(
                          'Add travellers from the trip’s People section.'),
                    ...widget.plan.people.map((p) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${p.title}${p.cancelled ? ' (archived)' : ''}'),
                          value: participants.contains(p.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              participants.add(p.id);
                            } else {
                              participants.remove(p.id);
                            }
                          }),
                        )),
                  ],
                ],
                if (kind == 'activity') ...[
                  dateField('date', 'Day'),
                  timeField('time', 'Time'),
                ],
                if (kind == 'booking') ...[
                  if (stay)
                    stayDurationField()
                  else
                    dateField('date', noStay ? 'Night' : 'Start date',
                        required: noStay),
                  if (!noStay) ...[
                    if (!stay) dateField('endDate', 'Arrival / end date'),
                    timeField('time',
                        stay ? 'Check-in time' : 'Departure / start time'),
                    timeField('endTime',
                        stay ? 'Check-out time' : 'Arrival / end time'),
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
                if (kind == 'booking' && !noStay)
                  text('confirmation', 'Confirmation / flight / train number'),
                if (kind == 'place') ...[
                  text(
                    'notes',
                    'Notes, opening hours, things to try',
                    lines: 3,
                  ),
                  PlanLinksEditor(
                    links: links,
                    onChanged: (v) => setState(() => links = v),
                  ),
                ],
                if (payable && !noStay)
                  ExpansionTile(
                    key: ValueKey('payment-${widget.item.id}'),
                    initiallyExpanded: widget.item['amount'].isNotEmpty ||
                        widget.item['paymentStatus'] == 'paid',
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Payment (optional)'),
                    subtitle: Text(
                      values['paymentStatus'] == 'paid'
                          ? 'Paid · included in spending'
                          : 'Add a cost or record a payment',
                    ),
                    children: [
                      TextFormField(
                          controller: _controllers['amount'],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                              labelText: 'Amount (optional until paid)',
                              helperText: stay
                                  ? 'Total for the entire stay, recorded once.'
                                  : null)),
                      const SizedBox(height: 12),
                      choice('currency', 'Currency',
                          AppConstants.travelCurrencies),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Paid'),
                          subtitle: const Text(
                              'Paid items appear in Trip spending automatically.'),
                          value: values['paymentStatus'] == 'paid',
                          onChanged: (paid) => setState(() =>
                              values['paymentStatus'] =
                                  paid ? 'paid' : 'unpaid')),
                      if (values['paymentStatus'] == 'paid')
                        dateField('paidDate', 'Payment date', required: true),
                    ],
                  ),
                if (kind == 'task') dateField('date', 'Due date'),
                const SizedBox(height: 8),
                Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 12),
                      title: const Text('More details',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          kind == 'task'
                              ? 'Notes and responsible person'
                              : kind == 'place'
                                  ? 'Status and priority'
                                  : 'Notes, status and external links',
                          style: const TextStyle(fontSize: 12)),
                      children: [
                        if (kind == 'activity')
                          DropdownButtonFormField<String>(
                            initialValue: values['placeId'] ?? '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Saved place',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('No linked place'),
                              ),
                              ...places.map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              values['placeId'] = v!;
                              values['expenseCategory'] = planExpenseCategory(
                                widget.plan.find(v)?['category'] ?? 'Activity',
                              );
                            }),
                          ),
                        choice(
                            'status',
                            'Status',
                            kind == 'task'
                                ? ['todo', 'completed']
                                : planStatuses),
                        if (kind == 'place')
                          choice('priority', 'Priority', planPriorities),
                        if (kind == 'activity')
                          timeField('endTime', 'End time'),
                        if (payable && !noStay)
                          choice('expenseCategory', 'Expense category',
                              AppConstants.travelCategories),
                        if (kind == 'booking' && !noStay) ...[
                          text('contact', 'Contact'),
                          text('timezone', 'Start time zone (e.g. Asia/Tokyo)'),
                          if (!stay)
                            text('endTimezone',
                                'Arrival time zone (e.g. America/Los_Angeles)'),
                          const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                  'Times are local to the stated time zone. No automatic time conversion.',
                                  style: TextStyle(fontSize: 12))),
                          dateField('cancelBy', 'Cancellation deadline'),
                        ],
                        if (kind == 'task')
                          text('assignee', 'Responsible person'),
                        if (kind != 'place')
                          text(
                              'notes',
                              kind == 'place'
                                  ? 'Notes, opening hours, things to try'
                                  : 'Notes',
                              lines: 3),
                        if (kind != 'task' && kind != 'place')
                          PlanLinksEditor(
                              links: links,
                              onChanged: (v) => setState(() => links = v)),
                      ],
                    )),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: save,
                    child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Save item'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
