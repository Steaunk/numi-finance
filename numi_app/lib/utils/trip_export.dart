import 'dart:convert';
import '../models/trip.dart';
import '../models/trip_plan.dart';

/// Export the current planner model without expenses, tasks, documents, private
/// trip notes or booking references (unless explicitly requested).
String tripPlanText(Trip trip, TripPlan plan,
    {bool includeReferences = false}) {
  final out = StringBuffer(
      '${trip.destination}\n${planDate(trip.startDate)} – ${planDate(trip.endDate)}\n');
  final arrangements = plan.items
      .where(
          (i) => (i.kind == 'activity' || i.kind == 'booking') && !i.cancelled)
      .toList();
  final dates = {
    ...tripDays(trip.startDate, trip.endDate).map(planDate),
    for (final item in arrangements)
      for (final field in ['date', 'endDate'])
        if (item[field].isNotEmpty) item[field],
  }.toList()
    ..sort();
  for (final day in [...dates, '']) {
    // Include stays on intervening nights as well as transport arrivals.
    final entries = <String, PlanItem>{
      for (final item in plan.timelineOn(day))
        if (!item.cancelled) item.id: item,
      if (day.isNotEmpty)
        for (final item in plan.bookingsOn(day))
          if (!item.cancelled) item.id: item,
    }.values.toList();
    String time(PlanItem item) => item['date'] != day && item['endDate'] != day
        ? ''
        : plan.timelineTime(item, day);
    entries.sort((a, b) => (time(a).isEmpty ? '99:99' : time(a))
        .compareTo(time(b).isEmpty ? '99:99' : time(b)));
    if (day.isEmpty && entries.isEmpty) continue;
    out.writeln('\n${day.isEmpty ? 'Unscheduled' : day}');
    final destinations = plan.destinationsOn(day).map((d) => d.title).toList();
    if (day.isNotEmpty && destinations.isNotEmpty) {
      out.writeln(destinations.join(' · '));
    }
    if (entries.isEmpty) out.writeln('Free day');
    for (final item in entries) {
      final at = time(item);
      final place = plan.find(item['placeId']);
      final category = place?['category'] ?? item['category'];
      out.writeln([
        '${at.isEmpty ? '' : '$at '}${plan.itemTitle(item)}',
        if (category.isNotEmpty) category,
        if (item.kind == 'booking' && item['status'].isNotEmpty) item['status'],
      ].join(' · '));
      if (item['endDate'].isNotEmpty || item['endTime'].isNotEmpty) {
        out.writeln(
            '  ${item['date']} ${item['time']} ${item['timezone']} → ${item['endDate'].isEmpty ? item['date'] : item['endDate']} ${item['endTime']} ${item['endTimezone']}');
      } else if (item['timezone'].isNotEmpty) {
        out.writeln('  Time zone: ${item['timezone']}');
      }
      if (item.isStay && item.stayDuration.isNotEmpty) {
        out.writeln('  ${item.stayDuration}');
      }
      final address = place?['address'] ?? item['address'];
      if (place != null) out.writeln('  ${place.title}');
      if (address.isNotEmpty) out.writeln('  $address');
      if (item['endAddress'].isNotEmpty) {
        out.writeln('  Arrive: ${item['endAddress']}');
      }
      if (item['notes'].isNotEmpty) out.writeln('  ${item['notes']}');
      if (includeReferences && item['confirmation'].isNotEmpty) {
        out.writeln('  Confirmation: ${item['confirmation']}');
      }
    }
  }
  final unplanned = plan
      .ofKind('place')
      .where((p) => !p.cancelled && !plan.isScheduled(p.id));
  if (unplanned.isNotEmpty) {
    out.writeln('\nPlaces to explore');
    for (final place in unplanned) {
      out.writeln(
          '• ${place.title}${place['address'].isEmpty ? '' : ' — ${place['address']}'}');
    }
  }
  return out.toString();
}

String tripPlanHtml(Trip trip, TripPlan plan,
    {bool includeReferences = false}) {
  const escape = HtmlEscape();
  final text = escape
      .convert(tripPlanText(trip, plan, includeReferences: includeReferences));
  return '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape.convert(trip.destination)} — Trip plan</title><style>body{font:16px/1.7 system-ui,sans-serif;max-width:800px;margin:40px auto;padding:0 24px;color:#222}pre{font:inherit;white-space:pre-wrap;overflow-wrap:anywhere}button{padding:12px 20px;border:0;border-radius:8px;background:#333;color:white;cursor:pointer}@media print{button{display:none}body{margin:0;max-width:none}}</style><button onclick="window.print()">Print / Save as PDF</button><pre>$text</pre></html>''';
}
