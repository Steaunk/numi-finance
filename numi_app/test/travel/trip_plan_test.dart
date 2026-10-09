import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/utils/trip_export.dart';

void main() {
  test('calendar days handle year boundaries', () {
    expect(tripDates(DateTime(2026, 12, 30), DateTime(2027, 1, 2)),
        ['2026-12-30', '2026-12-31', '2027-01-01', '2027-01-02']);
  });
  test('moving a multi-day booking preserves its duration and local times', () {
    final entry = PlanEntry(
        id: newTravelId(),
        title: 'Hotel',
        kind: 'hotel',
        date: '2026-10-10',
        endDate: '2026-10-13',
        time: '15:00');
    final moved = entry.movedTo('2026-10-12');
    expect(moved.endDate, '2026-10-15');
    expect(moved.time, '15:00');
    expect(moved.occursOn('2026-10-14'), isTrue);
    expect(moved.movedTo('').endDate, '');
  });
  test('reordering one day preserves other days and permits repeated places',
      () {
    final p = TripPlan(entries: [
      const PlanEntry(
          id: 'a', title: 'Breakfast', date: '2026-10-10', placeId: 'cafe'),
      const PlanEntry(id: 'b', title: 'Another day', date: '2026-10-11'),
      const PlanEntry(
          id: 'c', title: 'Lunch', date: '2026-10-10', placeId: 'cafe')
    ]);
    p.reorder('2026-10-10', ['c', 'a']);
    expect(p.entries.map((e) => e.id), ['c', 'b', 'a']);
    p.reorder('2026-10-10', ['missing', 'a']);
    expect(p.entries.map((e) => e.id), ['c', 'b', 'a']);
  });
  test('removing a saved place retains scheduled activities', () {
    final p = TripPlan(
        places: [const PlanPlace(id: 'p', title: 'Cafe')],
        entries: [const PlanEntry(id: 'e', title: 'Lunch', placeId: 'p')]);
    p.removePlace('p');
    expect(p.entries.single.placeId, '');
    expect(p.entries.single.title, 'Lunch');
  });
  test('export escapes untrusted text and omits booking references by default',
      () {
    final trip = Trip(
        id: 1,
        destination: '<script>alert(1)</script>',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11));
    final plan = TripPlan(entries: [
      const PlanEntry(
          id: 'e',
          title: 'Flight',
          kind: 'flight',
          date: '2026-10-10',
          confirmation: 'SECRET123')
    ]);
    final html = tripPlanHtml(trip, plan);
    expect(html, contains('&lt;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('SECRET123')));
    expect(tripPlanText(trip, plan, includeReferences: true),
        contains('SECRET123'));
  });
}
