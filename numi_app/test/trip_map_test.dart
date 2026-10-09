import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:numi_app/models/trip_map.dart';
import 'package:numi_app/models/trip_plan.dart';

void main() {
  test('Exact Google pin, not viewport, invalid coordinates or directions', () {
    final point = googleMapPoint(
        'https://www.google.com/maps/place/Pacific/@35.304,139.511,17z/data=!8m2!3d35.3044277!4d139.5135768');
    expect(point!.longitude, 139.5135768);
    for (final url in [
      'https://www.google.com/maps/@35,139,17z',
      'https://www.google.com/maps?ll=35,139',
      'https://www.google.com/maps/dir/?q=35,139',
      'https://evil.example/maps?q=35,139',
      'https://www.google.com/maps?q=NaN,139',
      'https://www.google.com/maps?q=91,139',
      'https://www.google.com/maps/%ZZ'
    ]) {
      expect(googleMapPoint(url), isNull, reason: url);
    }
    expect(
        googleMapPoint(
            'https://www.google.com/maps/search/?api=1&query=35%2C139'),
        const LatLng(35, 139));
  });
  test('Everyone, linked places, saved deduplication and person filters', () {
    final plan = TripPlan(items: [
      PlanItem({'id': 'a', 'kind': 'person', 'title': 'A'}),
      PlanItem({'id': 'b', 'kind': 'person', 'title': 'B'}),
      PlanItem({
        'id': 'p',
        'kind': 'place',
        'title': 'Museum',
        'latitude': '35',
        'longitude': '139',
        'destinationId': 'tokyo'
      }),
      PlanItem({
        'id': 'visit',
        'kind': 'activity',
        'placeId': 'p',
        'date': '2026-10-10'
      }),
      PlanItem({
        'id': 'solo',
        'kind': 'activity',
        'title': 'Solo',
        'date': '2026-10-10'
      }, participantIds: [
        'a'
      ]),
      PlanItem({
        'id': 'cancel',
        'kind': 'activity',
        'title': 'Cancelled',
        'status': 'cancelled',
        'date': '2026-10-10'
      }),
    ]);
    final stops = tripMapStops(plan, day: '2026-10-10', person: 'b');
    expect(stops.map((s) => s.item.id), ['visit']);
    expect(stops.single.point, const LatLng(35, 139));
    expect(tripMapStops(plan, day: '2026-10-11', savedPlaces: false), isEmpty);
    expect(tripMapStops(plan, day: '2026-10-11').single.item.id, 'p');
  });
  test(
      'Stay is visible through checkout and arrival pin never becomes departure',
      () {
    final plan = TripPlan(items: [
      PlanItem({
        'id': 'stay',
        'kind': 'booking',
        'category': 'Accommodation',
        'date': '2026-10-07',
        'endDate': '2026-10-09'
      }),
      PlanItem({
        'id': 'train',
        'kind': 'booking',
        'category': 'Train',
        'date': '2026-10-09',
        'endDate': '2026-10-09',
        'endAddress': 'Station'
      }, links: [
        const PlanLink(
            url: 'https://www.google.com/maps?q=35,139',
            label: 'Arrival map',
            purpose: 'Map')
      ]),
    ]);
    expect(tripMapStops(plan, day: '2026-10-08').single.item.id, 'stay');
    final stops = tripMapStops(plan, day: '2026-10-09');
    expect(stops.length, 3);
    expect(stops.firstWhere((s) => s.item.id == 'train' && !s.arrival).point,
        isNull);
    expect(stops.firstWhere((s) => s.arrival).point, const LatLng(35, 139));
    expect(tripMapStops(plan, day: '2026-10-10'), isEmpty);
  });
  test('Distances and directions retain both exact endpoints', () {
    expect(mapDistanceKm(const LatLng(0, 0), const LatLng(0, 1)),
        closeTo(111.195, 0.01));
    expect(mapDistanceKm(const LatLng(35, 139), const LatLng(35, 139)), 0);
    final link = mapDirections(const LatLng(35, 139), const LatLng(36, 140));
    expect(link.queryParameters['origin'], '35.0,139.0');
    expect(link.queryParameters['destination'], '36.0,140.0');
  });
}
