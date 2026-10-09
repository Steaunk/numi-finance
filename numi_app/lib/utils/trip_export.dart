import 'dart:convert';
import '../models/trip.dart';
import '../models/trip_plan.dart';

/// Export intentionally excludes costs, confirmation codes and private trip
/// notes; travellers can include booking references explicitly in the UI.
String tripPlanText(Trip trip, TripPlan plan,
    {bool includeReferences = false}) {
  final out = StringBuffer(
      '${trip.destination}\n${planDate(trip.startDate)} – ${planDate(trip.endDate)}\n');
  final dates = {
    ...tripDates(trip.startDate, trip.endDate),
    ...plan.entries.where((e) => e.date.isNotEmpty).map((e) => e.date)
  }.toList()
    ..sort();
  for (final day in [...dates, '']) {
    final entries = plan.entries
        .where((e) => day.isEmpty ? e.date.isEmpty : e.occursOn(day))
        .toList();
    if (day.isEmpty && entries.isEmpty) continue;
    out.writeln('\n${day.isEmpty ? 'Unscheduled' : day}');
    final note = plan.dayNotes[day];
    if (note != null && note.isNotEmpty) out.writeln(note);
    if (entries.isEmpty) out.writeln('Free day');
    for (final e in entries) {
      out.writeln(
          '${e.time.isEmpty || e.date != day ? '' : '${e.time} '}${e.title} · ${PlanEntry.kinds[e.kind]}${e.isBooking ? ' · ${e.status}' : ''}');
      if (e.endDate.isNotEmpty || e.endTime.isNotEmpty) {
        out.writeln(
            '  ${e.date} ${e.time} ${e.timezone} → ${e.endDate.isEmpty ? e.date : e.endDate} ${e.endTime} ${e.endTimezone}');
      }
      final place = plan.place(e.placeId);
      if (place != null) {
        out.writeln(
            '  ${place.title}${place.address.isEmpty ? '' : ' — ${place.address}'}');
      }
      if (e.notes.isNotEmpty) out.writeln('  ${e.notes}');
      if (includeReferences && e.confirmation.isNotEmpty) {
        out.writeln('  Confirmation: ${e.confirmation}');
      }
    }
  }
  final unplanned =
      plan.places.where((p) => !plan.entries.any((e) => e.placeId == p.id));
  if (unplanned.isNotEmpty) {
    out.writeln('\nPlaces to explore');
    for (final p in unplanned) {
      out.writeln('• ${p.title}${p.address.isEmpty ? '' : ' — ${p.address}'}');
    }
  }
  return out.toString();
}

String tripPlanHtml(Trip trip, TripPlan plan,
    {bool includeReferences = false}) {
  const escape = HtmlEscape();
  final text = escape
      .convert(tripPlanText(trip, plan, includeReferences: includeReferences));
  return '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape.convert(trip.destination)} — Trip plan</title><style>body{font:16px/1.7 system-ui,sans-serif;max-width:800px;margin:40px auto;padding:0 24px;color:#19342d}pre{font:inherit;white-space:pre-wrap;overflow-wrap:anywhere}button{padding:12px 20px;border:0;border-radius:8px;background:#19342d;color:white;cursor:pointer}@media print{button{display:none}body{margin:0;max-width:none}}</style><button onclick="window.print()">Print / Save as PDF</button><pre>$text</pre></html>''';
}
