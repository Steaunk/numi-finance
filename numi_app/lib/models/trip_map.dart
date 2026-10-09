import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'trip_plan.dart';

LatLng? mapPoint(String latitude, String longitude) {
  final lat = double.tryParse(latitude), lng = double.tryParse(longitude);
  if (lat == null ||
      lng == null ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return LatLng(lat, lng);
}

LatLng? googleMapPoint(String url) {
  if (linkPlatform(url) != 'Google Maps') return null;
  final uri = safeExternalLink(url);
  if (uri == null || uri.path.contains('/maps/dir/')) return null;
  String raw;
  try {
    raw = Uri.decodeFull('${uri.path}?${uri.query}');
  } on FormatException {
    return null;
  }
  final matches = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)')
      .allMatches(raw)
      .toList();
  if (matches.length == 1) {
    return mapPoint(matches.single[1]!, matches.single[2]!);
  }
  if (matches.length > 1) return null;
  for (final key in ['query', 'q']) {
    final m =
        RegExp(r'^(?:loc:)?\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$')
            .firstMatch(uri.queryParameters[key] ?? '');
    if (m != null) return mapPoint(m[1]!, m[2]!);
  }
  return null; // @lat,lng and ll= are camera positions, not place pins.
}

class TripMapStop {
  final PlanItem item, location;
  final bool arrival;
  final String title, day, time, address;
  final LatLng? point;
  const TripMapStop(
      {required this.item,
      required this.location,
      required this.arrival,
      required this.title,
      required this.day,
      required this.time,
      required this.address,
      required this.point});
  String get key => '${item.id}-${arrival ? 'arrival' : 'place'}';
  String get latitudeField => arrival ? 'endLatitude' : 'latitude';
  String get longitudeField => arrival ? 'endLongitude' : 'longitude';
  bool get saved => item.kind == 'place';
  String? get googleLink => location.links
      .where((l) =>
          l.platform == 'Google Maps' && (l.label == 'Arrival map') == arrival)
      .firstOrNull
      ?.url;
}

List<TripMapStop> tripMapStops(TripPlan plan,
    {String day = '',
    String destination = '',
    String person = '',
    bool savedPlaces = true}) {
  final stops = <TripMapStop>[];
  for (final item in plan.items) {
    if (item.cancelled ||
        !['place', 'activity', 'booking'].contains(item.kind) ||
        !plan.matchesDestination(item, destination)) {
      continue;
    }
    if (item.kind != 'place' && !plan.matchesPerson(item, person)) continue;
    if (item.kind == 'place' && !savedPlaces) continue;
    if (item.kind == 'booking' &&
        item['category'] == 'No accommodation needed') {
      continue;
    }
    final location = plan.find(item['placeId']) ?? item;
    void add(bool arrival) {
      final date = arrival ? item['endDate'] : item['date'];
      if (day.isNotEmpty && item.kind != 'place') {
        if (item.isStay) {
          if (item['date'].compareTo(day) > 0 ||
              item['endDate'].compareTo(day) < 0) {
            return;
          }
        } else if (date != day) {
          return;
        }
      }
      final lat = arrival ? location['endLatitude'] : location['latitude'];
      final lng = arrival ? location['endLongitude'] : location['longitude'];
      var point = mapPoint(lat, lng);
      if (point == null) {
        for (final link in location.links) {
          if ((link.label == 'Arrival map') != arrival) continue;
          point = googleMapPoint(link.url);
          if (point != null) break;
        }
      }
      stops.add(TripMapStop(
          item: item,
          location: location,
          arrival: arrival,
          title: '${plan.itemTitle(item)}${arrival ? ' · Arrival' : ''}',
          day: date,
          time: arrival ? item['endTime'] : item['time'],
          address: arrival ? item['endAddress'] : location['address'],
          point: point));
    }

    add(false);
    if (item.kind == 'booking' &&
        !item.isStay &&
        (item['endAddress'].isNotEmpty || item['endLatitude'].isNotEmpty)) {
      add(true);
    }
  }
  // Don't repeat a saved place already represented by a visible activity.
  final represented =
      stops.where((s) => !s.saved).map((s) => s.location.id).toSet();
  stops.removeWhere((s) => s.saved && represented.contains(s.location.id));
  stops.sort((a, b) {
    if (a.saved != b.saved) return a.saved ? 1 : -1;
    final order = '${a.day} ${a.time.isEmpty ? '99:99' : a.time}'
        .compareTo('${b.day} ${b.time.isEmpty ? '99:99' : b.time}');
    return order != 0
        ? order
        : plan.items.indexOf(a.item).compareTo(plan.items.indexOf(b.item));
  });
  return stops;
}

double mapDistanceKm(LatLng a, LatLng b) {
  double radians(double degrees) => degrees * math.pi / 180;
  final dlat = radians(b.latitude - a.latitude),
      dlng = radians(b.longitude - a.longitude);
  final h = math.pow(math.sin(dlat / 2), 2) +
      math.cos(radians(a.latitude)) *
          math.cos(radians(b.latitude)) *
          math.pow(math.sin(dlng / 2), 2);
  return 6371.0088 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
}

Uri mapDirections(LatLng from, LatLng to) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${from.latitude},${from.longitude}',
      'destination': '${to.latitude},${to.longitude}',
    });
