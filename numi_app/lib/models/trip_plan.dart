import 'dart:convert';
import 'dart:math';

String newTravelId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String planDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<String> tripDates(DateTime start, DateTime end) {
  final result = <String>[];
  // UTC calendar arithmetic avoids skipped/repeated days at DST boundaries.
  var date = DateTime.utc(start.year, start.month, start.day);
  final last = DateTime.utc(end.year, end.month, end.day);
  while (!date.isAfter(last)) {
    result.add(planDate(date));
    date = date.add(const Duration(days: 1));
  }
  return result;
}

class PlanPlace {
  final String id, title, address, notes, url;
  final double? lat, lng;
  const PlanPlace(
      {required this.id,
      required this.title,
      this.address = '',
      this.notes = '',
      this.url = '',
      this.lat,
      this.lng});
  factory PlanPlace.fromJson(Map<String, dynamic> j) => PlanPlace(
      id: j['id'],
      title: j['title'],
      address: j['address'] ?? '',
      notes: j['notes'] ?? '',
      url: j['url'] ?? '',
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble());
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'address': address,
        'notes': notes,
        'url': url,
        'lat': lat,
        'lng': lng
      };
  bool get hasCoordinates => lat != null && lng != null;
}

class PlanEntry {
  static const kinds = {
    'activity': 'Activity',
    'food': 'Food',
    'transport': 'Transport',
    'note': 'Note',
    'hotel': 'Hotel',
    'flight': 'Flight',
    'train': 'Train',
    'booking': 'Other booking'
  };
  final String id,
      title,
      kind,
      date,
      time,
      endDate,
      endTime,
      placeId,
      notes,
      status,
      confirmation,
      timezone,
      endTimezone,
      url;
  const PlanEntry(
      {required this.id,
      required this.title,
      this.kind = 'activity',
      this.date = '',
      this.time = '',
      this.endDate = '',
      this.endTime = '',
      this.placeId = '',
      this.notes = '',
      this.status = 'pending',
      this.confirmation = '',
      this.timezone = '',
      this.endTimezone = '',
      this.url = ''});
  bool get isBooking =>
      const ['hotel', 'flight', 'train', 'booking'].contains(kind);
  bool occursOn(String day) =>
      date == day ||
      (date.isNotEmpty &&
          endDate.isNotEmpty &&
          day.compareTo(date) >= 0 &&
          day.compareTo(endDate) <= 0);
  String get category => switch (kind) {
        'hotel' => 'Accommodation',
        'flight' || 'train' || 'transport' => 'Transportation',
        'food' => 'Food & Drinks',
        'activity' => 'Sightseeing',
        _ => 'Other'
      };
  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
      id: j['id'],
      title: j['title'],
      kind: j['kind'] ?? 'activity',
      date: j['date'] ?? '',
      time: j['time'] ?? '',
      endDate: j['end_date'] ?? '',
      endTime: j['end_time'] ?? '',
      placeId: j['place_id'] ?? '',
      notes: j['notes'] ?? '',
      status: j['status'] ?? 'pending',
      confirmation: j['confirmation'] ?? '',
      timezone: j['timezone'] ?? '',
      endTimezone: j['end_timezone'] ?? '',
      url: j['url'] ?? '');
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'date': date,
        'time': time,
        'end_date': endDate,
        'end_time': endTime,
        'place_id': placeId,
        'notes': notes,
        'status': status,
        'confirmation': confirmation,
        'timezone': timezone,
        'end_timezone': endTimezone,
        'url': url
      };
  PlanEntry movedTo(String day) {
    String end = endDate;
    if (end.isNotEmpty && date.isNotEmpty && day.isNotEmpty) {
      final duration = DateTime.parse('${endDate}T00:00:00Z')
          .difference(DateTime.parse('${date}T00:00:00Z'));
      end = planDate(DateTime.parse('${day}T00:00:00Z').add(duration));
    }
    if (day.isEmpty) end = '';
    return PlanEntry.fromJson({...toJson(), 'date': day, 'end_date': end});
  }
}

class PlanCheck {
  final String id, title, kind, due, notes;
  final bool done;
  const PlanCheck(
      {required this.id,
      required this.title,
      this.kind = 'packing',
      this.due = '',
      this.notes = '',
      this.done = false});
  factory PlanCheck.fromJson(Map<String, dynamic> j) => PlanCheck(
      id: j['id'],
      title: j['title'],
      kind: j['kind'] ?? 'packing',
      due: j['due'] ?? '',
      notes: j['notes'] ?? '',
      done: j['done'] ?? false);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind,
        'due': due,
        'notes': notes,
        'done': done
      };
}

class TripPlan {
  final List<PlanPlace> places;
  final List<PlanEntry> entries;
  final List<PlanCheck> checks;
  final Map<String, String> dayNotes;
  TripPlan(
      {List<PlanPlace>? places,
      List<PlanEntry>? entries,
      List<PlanCheck>? checks,
      Map<String, String>? dayNotes})
      : places = places ?? [],
        entries = entries ?? [],
        checks = checks ?? [],
        dayNotes = dayNotes ?? {};
  factory TripPlan.fromJson(Map<String, dynamic> j) => TripPlan(
        places: (j['places'] as List? ?? [])
            .map((v) => PlanPlace.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        entries: (j['entries'] as List? ?? [])
            .map((v) => PlanEntry.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        checks: (j['checks'] as List? ?? [])
            .map((v) => PlanCheck.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        dayNotes: Map<String, String>.from(j['day_notes'] ?? {}),
      );
  factory TripPlan.decode(String value) =>
      TripPlan.fromJson(jsonDecode(value) as Map<String, dynamic>);
  Map<String, dynamic> toJson() => {
        'places': places.map((p) => p.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'checks': checks.map((c) => c.toJson()).toList(),
        'day_notes': dayNotes
      };
  String encode() => jsonEncode(toJson());
  PlanPlace? place(String id) => places.where((p) => p.id == id).firstOrNull;
  PlanEntry? entry(String id) => entries.where((e) => e.id == id).firstOrNull;
  void savePlace(PlanPlace place) {
    final i = places.indexWhere((p) => p.id == place.id);
    if (i < 0) {
      places.add(place);
    } else {
      places[i] = place;
    }
  }

  void saveEntry(PlanEntry entry) {
    final i = entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) {
      entries.add(entry);
    } else {
      entries[i] = entry;
    }
  }

  void saveCheck(PlanCheck check) {
    final i = checks.indexWhere((c) => c.id == check.id);
    if (i < 0) {
      checks.add(check);
    } else {
      checks[i] = check;
    }
  }

  void removePlace(String id) {
    places.removeWhere((p) => p.id == id);
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].placeId == id) {
        entries[i] =
            PlanEntry.fromJson({...entries[i].toJson(), 'place_id': ''});
      }
    }
  }

  void reorder(String day, List<String> ids) {
    // Only reorder slots on this day, preserving all other entries and bookings.
    final existing =
        entries.where((e) => e.date == day).map((e) => e.id).toSet();
    if (ids.length != existing.length ||
        ids.toSet().length != ids.length ||
        !ids.toSet().containsAll(existing)) {
      return;
    }
    final byId = {for (final e in entries) e.id: e};
    var index = 0;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].date == day) entries[i] = byId[ids[index++]]!;
    }
  }
}
