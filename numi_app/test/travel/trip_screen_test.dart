import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/travel/screens/trip_detail_screen.dart';

void main() {
  testWidgets(
      'phone: add an activity, link a real expense, and check packing items offline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    final travel = TravelRepository(db, null, RateRepository(db, null));
    final planner = TripPlanRepository(db, null, travel);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await travel.addTrip(
        destination: 'Kyoto',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12));
    final id = (await db.select(db.trips).getSingle()).id;
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPrefsProvider.overrideWithValue(prefs),
      travelRepositoryProvider.overrideWithValue(travel),
      tripPlanRepositoryProvider.overrideWithValue(planner),
      connectivityProvider.overrideWith((ref) => Stream.value(false)),
    ], child: MaterialApp(home: TripDetailScreen(tripId: id))));
    await tester.pumpAndSettle();
    expect(find.text('Kyoto'), findsOneWidget);
    expect(find.text('A day with room to explore.'), findsOneWidget);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), 'Fushimi Inari');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Fushimi Inari'), findsOneWidget);
    final entry =
        TripPlan.decode((await db.select(db.tripPlans).getSingle()).document)
            .entries
            .single;
    expect(entry.date, '2026-10-10');
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Fushimi Inari'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '15');
    await tester.ensureVisible(find.text('Add Expense'));
    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();
    final expense = (await db.select(db.travelExpenses).get()).single;
    expect(expense.plannerEntryId, entry.id);
    expect(expense.amount, 15);
    await tester.ensureVisible(find.text('Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start with travel essentials'));
    await tester.pumpAndSettle();
    expect(find.text('Passport / ID'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
        TripPlan.decode((await db.select(db.tripPlans).getSingle()).document)
            .checks
            .first
            .done,
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('desktop: booking spans days and conflict controls remain usable',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    final travel = TravelRepository(db, null, RateRepository(db, null));
    final planner = TripPlanRepository(db, null, travel);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await travel.addTrip(
        destination: 'Kyoto',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12));
    final id = (await db.select(db.trips).getSingle()).id;
    await planner.edit(
        id,
        (p) => p.saveEntry(PlanEntry(
            id: 'h' * 32,
            title: 'Kyoto hotel',
            kind: 'hotel',
            date: '2026-10-10',
            endDate: '2026-10-12',
            status: 'confirmed',
            confirmation: 'ABC123')));
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPrefsProvider.overrideWithValue(prefs),
      travelRepositoryProvider.overrideWithValue(travel),
      tripPlanRepositoryProvider.overrideWithValue(planner),
      connectivityProvider.overrideWith((ref) => Stream.value(false))
    ], child: MaterialApp(home: TripDetailScreen(tripId: id))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-2026-10-11')));
    await tester.pumpAndSettle();
    expect(find.text('Kyoto hotel'), findsOneWidget);
    expect(find.textContaining('Continues from 2026-10-10'), findsOneWidget);
    expect(find.text('Confirmation: ABC123'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await db.close();
  });
}
