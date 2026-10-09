import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/ui/travel/widgets/plan_map.dart';

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aNuoAAAAASUVORK5CYII='));
}

void main() {
  testWidgets(
      'map filters by day, supports zero coordinates, pin actions and long-press creation',
      (tester) async {
    final plan = TripPlan(places: [
      const PlanPlace(id: 'a', title: 'Today', lat: 0, lng: 0),
      const PlanPlace(id: 'b', title: 'Tomorrow', lat: 1, lng: 1),
      const PlanPlace(id: 'c', title: 'Address only', address: 'A street')
    ], entries: [
      const PlanEntry(
          id: 'e', title: 'Visit', placeId: 'a', date: '2026-10-10'),
      const PlanEntry(
          id: 'f', title: 'Another visit', placeId: 'b', date: '2026-10-11')
    ]);
    PlanPlace? selected;
    var added = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlanMap(
                plan: plan,
                day: '2026-10-10',
                tileProvider: _TestTiles(),
                onPlace: (p) => selected = p,
                onAdd: (lat, lng) => added = true))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Today'), findsOneWidget);
    expect(find.byTooltip('Tomorrow'), findsNothing);
    await tester.tap(find.byTooltip('Today'));
    expect(selected?.id, 'a');
    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.longPressAt(center + const Offset(80, 60));
    await tester.pumpAndSettle();
    expect(added, isTrue);
    expect(tester.takeException(), isNull);
  });
}
