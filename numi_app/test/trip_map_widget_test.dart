import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/travel/screens/trip_map_screen.dart';

class TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg=='));
}

void main() {
  late AppDatabase db;
  late TripPlanRepository repo;
  late Trip trip;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TripPlanRepository(db, null);
    final id = await db.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11)));
    trip = Trip(
        id: id,
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 11));
    await repo.save(
        id,
        PlanItem({
          'id': 'museum',
          'kind': 'activity',
          'title': 'Museum',
          'date': '2026-10-10'
        }));
  });
  tearDown(() async => db.close());
  testWidgets('Phone: locate a place, render pin, filter out and return',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [tripPlanRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            home: TripMapScreen(trip: trip, tileProvider: TestTiles()))));
    await tester.pumpAndSettle();
    expect(find.text('0 mapped · 1 to locate'), findsOneWidget);
    await tester.tap(find.text('Locate'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'https://www.google.com/maps?q=35.69,139.72');
    await tester.tap(find.widgetWithText(FilledButton, 'Locate'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('1 mapped · 0 to locate'), findsOneWidget);
    expect(
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .find('museum')!['longitude'],
        '139.72');
    final day = find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == 'Day');
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-10-11').last);
    await tester.pumpAndSettle();
    expect(find.text('0 mapped · 0 to locate'), findsOneWidget);
    await tester.tap(day);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-10-10').last);
    await tester.pumpAndSettle();
    expect(find.text('1 mapped · 0 to locate'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
