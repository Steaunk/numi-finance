import 'dart:convert';
import 'dart:math';

String newPlanId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

const placeCategories = [
  'Accommodation',
  'Sightseeing',
  'Restaurant',
  'Cafe',
  'Shopping',
  'Park',
  'Practical',
  'Other'
];
const bookingCategories = [
  'Accommodation',
  'Flight',
  'Train',
  'Bus',
  'Car rental',
  'Reservation',
  'No accommodation needed'
];
const taskCategories = ['Preparation', 'Packing', 'Shopping'];
const planPriorities = ['Must go', 'If nearby', 'Nice to have'];
const planStatuses = [
  'planned',
  'confirmed',
  'completed',
  'skipped',
  'cancelled'
];
const linkPurposes = ['Map', 'Website', 'Booking', 'Guide', 'Other'];

class PlanLink {
  final String purpose;
  final String label;
  final String url;
  const PlanLink({this.purpose = 'Other', this.label = '', required this.url});
  factory PlanLink.fromJson(Map<String, dynamic> json) => PlanLink(
      purpose: json['purpose'] as String? ?? 'Other',
      label: json['label'] as String? ?? '',
      url: json['url'] as String);
  Map<String, String> toJson() =>
      {'purpose': purpose, 'label': label, 'url': url};
  String get platform => linkPlatform(url);
  String get displayName => label.isEmpty ? platform : label;
}

class PlanItem {
  final Map<String, String> fields;
  final List<PlanLink> links;
  final List<String> participantIds;
  PlanItem(Map<String, String> fields,
      {List<PlanLink> links = const [], List<String> participantIds = const []})
      : fields = Map.unmodifiable(fields),
        links = List.unmodifiable(links),
        participantIds = List.unmodifiable(participantIds);
  String operator [](String key) => fields[key] ?? '';
  String get id => this['id'];
  String get kind => this['kind'];
  String get title => this['title'];
  bool get cancelled =>
      this['status'] == 'cancelled' || this['status'] == 'skipped';
  bool get isStay => kind == 'booking' && this['category'] == 'Accommodation';
  int? get stayNights {
    if (!isStay) return null;
    final start = DateTime.tryParse(this['date']);
    final end = DateTime.tryParse(this['endDate']);
    if (start == null || end == null) return null;
    final nights = DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return nights > 0 ? nights : null;
  }

  String get stayDuration => stayNights == null
      ? ''
      : '${stayNights!} ${stayNights == 1 ? 'night' : 'nights'}';
  PlanItem copy(Map<String, String> changes,
          {List<PlanLink>? links, List<String>? participantIds}) =>
      PlanItem({...fields, ...changes},
          links: links ?? this.links,
          participantIds: participantIds ?? this.participantIds);
  Map<String, dynamic> toJson() => {
        ...fields,
        'links': links.map((l) => l.toJson()).toList(),
        if (participantIds.isNotEmpty) 'participantIds': participantIds
      };
  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem({
        for (final e in json.entries)
          if (e.key != 'links' && e.key != 'participantIds')
            e.key: e.value as String
      },
          participantIds:
              (json['participantIds'] as List? ?? []).cast<String>(),
          links: (json['links'] as List? ?? [])
              .map(
                  (l) => PlanLink.fromJson(Map<String, dynamic>.from(l as Map)))
              .toList());
  factory PlanItem.create(String kind) => PlanItem({
        'id': newPlanId(),
        'kind': kind,
        'title': '',
        'status': kind == 'task' ? 'todo' : 'planned',
        'category': switch (kind) {
          'place' => 'Sightseeing',
          'booking' => 'Accommodation',
          'task' => 'Preparation',
          'destination' => 'Destination',
          _ => 'Activity'
        },
        'priority': 'Nice to have',
      });
}

class TripPlan {
  final List<PlanItem> items;
  final bool pending;
  final String error;
  TripPlan(
      {List<PlanItem> items = const [], this.pending = false, this.error = ''})
      : items = List.unmodifiable(items);
  factory TripPlan.decode(String raw,
      {bool pending = false, String error = ''}) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return TripPlan(
        items: (json['items'] as List? ?? [])
            .map((i) => PlanItem.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList(),
        pending: pending,
        error: error);
  }
  String encode() =>
      jsonEncode({'items': items.map((i) => i.toJson()).toList()});
  List<PlanItem> ofKind(String kind) =>
      items.where((i) => i.kind == kind).toList();
  PlanItem? find(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isScheduled(String id) => ofKind('activity')
      .any((i) => i['placeId'] == id && i['date'].isNotEmpty && !i.cancelled);
  String itemTitle(PlanItem item) => item.title.isNotEmpty
      ? item.title
      : find(item['placeId'])?.title ?? 'Activity';
  List<PlanItem> get people => ofKind('person');
  List<PlanItem> get activePeople => people.where((p) => !p.cancelled).toList();
  bool matchesPerson(PlanItem item, String personId) =>
      personId.isEmpty ||
      (item.participantIds.isEmpty
          ? find(personId)?.cancelled != true
          : item.participantIds.contains(personId));
  String participantsLabel(PlanItem item) => item.participantIds.isEmpty
      ? 'Everyone'
      : item.participantIds
          .map((id) => find(id)?.title ?? 'Archived person')
          .join(', ');
  List<PlanItem> get destinations => ofKind('destination');
  List<PlanItem> destinationsOn(String day) => destinations
      .where((d) =>
          !d.cancelled &&
          d['date'].compareTo(day) <= 0 &&
          d['endDate'].compareTo(day) >= 0)
      .toList();
  String destinationIdFor(PlanItem item) => item['placeId'].isNotEmpty
      ? (find(item['placeId'])?['destinationId'] ?? '')
      : item['destinationId'];
  String destinationLabel(PlanItem item) {
    final from = find(destinationIdFor(item))?.title ?? '';
    final to = find(item['endDestinationId'])?.title ?? '';
    return to.isNotEmpty && item['endDestinationId'] != destinationIdFor(item)
        ? '${from.isEmpty ? 'Outside trip' : from} → $to'
        : from;
  }

  bool matchesDestination(PlanItem item, String id) =>
      id.isEmpty ||
      (id == '__unassigned__'
          ? destinationIdFor(item).isEmpty && item['endDestinationId'].isEmpty
          : id == '__transfers__'
              ? item['endDestinationId'].isNotEmpty &&
                  item['endDestinationId'] != destinationIdFor(item)
              : destinationIdFor(item) == id || item['endDestinationId'] == id);
  String expenseDestination(String? itemId, {String destinationId = ''}) {
    final item = find(itemId ?? '');
    if (item == null) {
      return find(destinationId)?.kind == 'destination' ? destinationId : '';
    }
    final from = destinationIdFor(item), to = item['endDestinationId'];
    if (to.isNotEmpty && to != from) return '__transfers__';
    return from;
  }

  String expenseDestinationLabel(String id) => id == '__transfers__'
      ? 'Between destinations'
      : find(id)?.title ?? 'Unassigned';
  List<PlanItem> timelineOn(String day,
      {String destination = '', String person = ''}) {
    final entries = items
        .where(
          (i) =>
              matchesDestination(i, destination) &&
              matchesPerson(i, person) &&
              ((i.kind == 'activity' && i['date'] == day) ||
                  (day.isNotEmpty &&
                      i.kind == 'booking' &&
                      i['category'] != 'No accommodation needed' &&
                      (i['category'] == 'Accommodation'
                          ? i['endDate'] == day
                          : i['date'] == day || i['endDate'] == day))),
        )
        .toList();
    final order = {
      for (var index = 0; index < entries.length; index++)
        entries[index].id: index,
    };
    entries.sort((a, b) {
      final at = timelineTime(a, day), bt = timelineTime(b, day);
      final result = (at.isEmpty ? '99:99' : at).compareTo(
        bt.isEmpty ? '99:99' : bt,
      );
      return result == 0 ? order[a.id]!.compareTo(order[b.id]!) : result;
    });
    return entries;
  }

  String timelineTime(PlanItem item, String day) =>
      item.kind == 'booking' && item['endDate'] == day && item['date'] != day
          ? item['endTime']
          : item['time'];

  bool hasStay(String day, {String person = ''}) => ofKind('booking').any((i) =>
      !i.cancelled &&
      matchesPerson(i, person) &&
      ((i['category'] == 'No accommodation needed' && i['date'] == day) ||
          (i['category'] == 'Accommodation' &&
              i['date'].isNotEmpty &&
              i['endDate'].isNotEmpty &&
              i['date'].compareTo(day) <= 0 &&
              i['endDate'].compareTo(day) > 0)));
  List<PlanItem> bookingsOn(String day) => ofKind('booking')
      .where((i) =>
          i['date'] == day ||
          i['endDate'] == day ||
          (i['category'] == 'Accommodation' &&
              i['date'].isNotEmpty &&
              i['endDate'].isNotEmpty &&
              i['date'].compareTo(day) < 0 &&
              i['endDate'].compareTo(day) > 0))
      .toList();
}

String planDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
List<DateTime> tripDays(DateTime start, DateTime end) {
  final result = <DateTime>[];
  for (var day = DateTime(start.year, start.month, start.day);
      !day.isAfter(DateTime(end.year, end.month, end.day));
      day = DateTime(day.year, day.month, day.day + 1)) {
    result.add(day);
  }
  return result;
}

String tripPhase(DateTime start, DateTime end, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(DateTime(start.year, start.month, start.day))) {
    return 'Upcoming';
  }
  if (today.isAfter(DateTime(end.year, end.month, end.day))) return 'Completed';
  return 'Travelling';
}

Uri? safeExternalLink(String value) {
  try {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(value.trim())) {
      return null;
    }
    return uri;
  } on FormatException {
    return null;
  }
}

List<String> extractPlanLinks(String input) =>
    RegExp(r'''https?://[^\s<>"“”]+''', caseSensitive: false)
        .allMatches(input)
        .map((m) => m.group(0)!.replaceAll(RegExp(r'[.,;!，。；！、）)\]】]+$'), ''))
        .where((s) => safeExternalLink(s) != null)
        .toSet()
        .toList();
Uri mapSearchLink(String title, String address) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': address.trim().isEmpty ? title : '$title $address'});
Uri baiduMapSearchLink(String title, String address, String destination) =>
    Uri.https('api.map.baidu.com', '/place/search', {
      'query':
          [title.trim(), address.trim()].where((v) => v.isNotEmpty).join(' '),
      'region': destination.trim().isEmpty ? '全国' : destination.trim(),
      'output': 'html',
      'src': 'webapp.steaunk.numi',
    });
String linkPlatform(String url) {
  final host = safeExternalLink(url)?.host.toLowerCase() ?? '';
  const platforms = {
    'google.com': 'Google Maps',
    'maps.app.goo.gl': 'Google Maps',
    'goo.gl': 'Google Maps',
    'g.co': 'Google Maps',
    'google.co.jp': 'Google Maps',
    'google.co.uk': 'Google Maps',
    'google.com.sg': 'Google Maps',
    'google.com.hk': 'Google Maps',
    'amap.com': 'Amap',
    'gaode.com': 'Amap',
    'baidu.com': 'Baidu Maps',
    'booking.com': 'Booking.com',
    'agoda.com': 'Agoda',
    'airbnb.com': 'Airbnb',
    'airbnb.co.uk': 'Airbnb',
    'airbnb.com.sg': 'Airbnb',
    'airbnb.com.hk': 'Airbnb',
    'airbnb.jp': 'Airbnb',
    'airbnb.cn': 'Airbnb',
    'abnb.me': 'Airbnb',
    'trip.com.hk': 'Trip.com',
    'trip.com': 'Trip.com',
    'ctrip.com': 'Ctrip',
    'klook.com': 'Klook',
    'kkday.com': 'KKday',
    'getyourguide.com': 'GetYourGuide',
    'xiaohongshu.com': 'Xiaohongshu',
    'xhslink.com': 'Xiaohongshu',
    'instagram.com': 'Instagram',
    'tripadvisor.com': 'Tripadvisor',
  };
  for (final e in platforms.entries) {
    if (host == e.key || host.endsWith('.${e.key}')) return e.value;
  }
  return host.isEmpty ? 'Website' : host;
}

String planExpenseCategory(String category) => switch (category) {
      'Accommodation' => 'Accommodation',
      'Flight' || 'Train' || 'Bus' || 'Car rental' => 'Transportation',
      'Sightseeing' => 'Sightseeing',
      'Restaurant' || 'Cafe' => 'Food & Drinks',
      'Shopping' => 'Shopping',
      _ => 'Other',
    };

/// Rebase edits made while a request was in flight onto its merged response.
/// Throws instead of silently replacing a concurrent field edit.
TripPlan mergePlanChanges(TripPlan base, TripPlan local, TripPlan remote) {
  bool equal(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && equal(a[k], b[k]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => equal(a[i], b[i]));
    }
    return a == b;
  }

  final b = {for (final i in base.items) i.id: i.toJson()};
  final l = {for (final i in local.items) i.id: i.toJson()};
  final r = {
    for (final i in remote.items) i.id: Map<String, dynamic>.of(i.toJson())
  };
  for (final id in {...b.keys, ...l.keys}) {
    final old = b[id], next = l[id], current = r[id];
    if (equal(old, next) || equal(next, current)) continue;
    if (old == null || next == null || current == null) {
      if (!equal(current, old)) throw StateError('conflict');
      if (next == null) {
        r.remove(id);
      } else {
        r[id] = Map.of(next);
      }
      continue;
    }
    for (final field in {...old.keys, ...next.keys}) {
      if (equal(old[field], next[field]) ||
          equal(current[field], next[field])) {
        continue;
      }
      if (!equal(current[field], old[field])) throw StateError('conflict');
      if (next.containsKey(field)) {
        current[field] = next[field];
      } else {
        current.remove(field);
      }
    }
  }
  final common =
      b.keys.toSet().intersection(l.keys.toSet()).intersection(r.keys.toSet());
  List<String> order(TripPlan p) =>
      p.items.map((i) => i.id).where(common.contains).toList();
  final reordered = !equal(order(base), order(local));
  if (reordered &&
      !equal(order(base), order(remote)) &&
      !equal(order(local), order(remote))) {
    throw StateError('conflict');
  }
  final ids = {
    ...(reordered ? local : remote).items.map((i) => i.id),
    ...local.items.map((i) => i.id),
    ...r.keys
  };
  return TripPlan(
      items: ids
          .where(r.containsKey)
          .map((id) => PlanItem.fromJson(r[id]!))
          .toList());
}
