import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/models/travel_expense.dart';
import 'package:numi_app/utils/trip_export.dart';

void main() {
  final trip = Trip(
    id: 1,
    destination: 'Kyoto <autumn>',
    startDate: DateTime(2026, 10, 10),
    endDate: DateTime(2026, 10, 12),
    notes: 'PRIVATE TRIP NOTE',
    expenses: [
      TravelExpense(
          id: 1,
          tripId: 1,
          amount: 12345,
          currency: 'SGD',
          date: DateTime(2026, 10, 10),
          category: 'Other',
          name: 'PRIVATE EXPENSE')
    ],
  );
  final plan = TripPlan(items: [
    PlanItem({
      'id': 'destination',
      'kind': 'destination',
      'title': 'Kyoto city',
      'date': '2026-10-10',
      'endDate': '2026-10-12'
    }),
    PlanItem({
      'id': 'place',
      'kind': 'place',
      'title': 'Shrine walk',
      'address': 'Fushimi',
      'category': 'Sightseeing'
    }),
    PlanItem({
      'id': 'activity',
      'kind': 'activity',
      'placeId': 'place',
      'date': '2026-10-11',
      'time': '09:00',
      'notes': '<script>alert(1)</script>'
    }),
    PlanItem({
      'id': 'hotel',
      'kind': 'booking',
      'category': 'Accommodation',
      'title': 'Riverside hotel',
      'date': '2026-10-10',
      'endDate': '2026-10-12',
      'time': '15:00',
      'endTime': '11:00',
      'status': 'confirmed',
      'confirmation': 'SECRET-123',
      'documentId': 'PRIVATE DOCUMENT'
    }),
    PlanItem({
      'id': 'flight',
      'kind': 'booking',
      'category': 'Flight',
      'title': 'Overnight flight',
      'date': '2026-10-10',
      'endDate': '2026-10-11',
      'time': '23:00',
      'endTime': '07:00',
      'timezone': 'Asia/Singapore',
      'endTimezone': 'Asia/Tokyo'
    }),
    PlanItem({
      'id': 'unscheduled',
      'kind': 'booking',
      'category': 'Train',
      'title': 'Anytime train'
    }),
    PlanItem({'id': 'idea', 'kind': 'place', 'title': 'Garden idea'}),
    PlanItem({'id': 'task', 'kind': 'task', 'title': 'PRIVATE TASK'}),
    PlanItem({
      'id': 'cancelled',
      'kind': 'activity',
      'title': 'CANCELLED ITEM',
      'date': '2026-10-11',
      'status': 'cancelled'
    }),
  ]);

  test(
      'current planner exports destinations, stays, arrivals and unscheduled ideas',
      () {
    final text = tripPlanText(trip, plan);
    final middleDay =
        text.split('\n2026-10-11\n')[1].split('\n2026-10-12\n')[0];
    expect(middleDay, contains('Kyoto city'));
    expect(middleDay, contains('Riverside hotel'));
    expect(middleDay, contains('2 nights'));
    expect(middleDay, contains('07:00 Overnight flight'));
    expect(middleDay.indexOf('Overnight flight'),
        lessThan(middleDay.indexOf('Shrine walk')));
    expect(middleDay, contains('Asia/Singapore'));
    expect(middleDay, contains('Asia/Tokyo'));
    expect(text, contains('11:00 Riverside hotel'));
    expect(text, contains('Unscheduled\nAnytime train'));
    expect(text.split('Places to explore').last, contains('Garden idea'));
    expect(
        text.split('Places to explore').last, isNot(contains('Shrine walk')));
  });

  test('private fields stay excluded and references require opt-in', () {
    final text = tripPlanText(trip, plan);
    for (final secret in ['PRIVATE', '12345', 'SECRET-123', 'CANCELLED ITEM']) {
      expect(text, isNot(contains(secret)));
    }
    final withReferences = tripPlanText(trip, plan, includeReferences: true);
    expect(withReferences, contains('Confirmation: SECRET-123'));
    expect(withReferences, isNot(contains('PRIVATE')));
  });

  test('printable HTML escapes user content and omits references by default',
      () {
    final html = tripPlanHtml(trip, plan);
    expect(html, contains('Kyoto &lt;autumn&gt;'));
    expect(html, contains('&lt;script&gt;alert(1)&lt;&#47;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, isNot(contains('SECRET-123')));
    expect(tripPlanHtml(trip, plan, includeReferences: true),
        contains('SECRET-123'));
  });
}
