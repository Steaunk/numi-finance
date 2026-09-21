import 'dart:convert';
import 'dart:math';

String newPlanId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

const placeCategories = [
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
  PlanItem(Map<String, String> fields, {List<PlanLink> links = const []})
      : fields = Map.unmodifiable(fields),
        links = List.unmodifiable(links);
  String operator [](String key) => fields[key] ?? '';
  String get id => this['id'];
  String get kind => this['kind'];
  String get title => this['title'];
  bool get cancelled =>
      this['status'] == 'cancelled' || this['status'] == 'skipped';
  PlanItem copy(Map<String, String> changes, {List<PlanLink>? links}) =>
      PlanItem({...fields, ...changes}, links: links ?? this.links);
  Map<String, dynamic> toJson() =>
      {...fields, 'links': links.map((l) => l.toJson()).toList()};
  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem({
        for (final e in json.entries)
          if (e.key != 'links') e.key: e.value as String
      },
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
  bool hasStay(String day) => ofKind('booking').any((i) =>
      !i.cancelled &&
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
    'amap.com': 'Amap',
    'gaode.com': 'Amap',
    'baidu.com': 'Baidu Maps',
    'booking.com': 'Booking.com',
    'agoda.com': 'Agoda',
    'airbnb.com': 'Airbnb',
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
