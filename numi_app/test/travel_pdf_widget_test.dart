import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:go_router/go_router.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/remote/api_client.dart';
import 'package:numi_app/data/remote/endpoints/travel_api.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/travel/screens/import_travel_screen.dart';

class PdfApi extends TravelApi {
  PdfApi() : super(ApiClient('https://example.test'));
  int uploads = 0;
  @override
  Future<Map<String, dynamic>> previewPdf(List<int> bytes, String name) async {
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    return {
      'items': [
        {
          'kind': 'activity',
          'title': 'Museum',
          'date': '2026-10-10',
          'time': '11:00',
          'source': 'PDF ticket',
          'notes': 'Venue: Museum\nDate: 2026-10-10 11:00'
        }
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> attachPdf(
      int id, List<int> bytes, String name) async {
    expect(id, 4);
    uploads++;
    return {'id': 'f78b0f4b-6643-4215-90eb-e050c871979b', 'name': 'Ticket.pdf'};
  }
}

void main() {
  late AppDatabase db;
  late TripPlanRepository repo;
  late Trip trip;
  late File file;
  late PdfApi api;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TripPlanRepository(db, null);
    api = PdfApi();
    final id = await db.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12),
        remoteId: const Value(4)));
    trip = Trip(
        id: id,
        remoteId: 4,
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12));
    final dir = await Directory.systemTemp.createTemp('numi-pdf-widget-');
    file = File('${dir.path}/Ticket.pdf');
    await file.writeAsString('%PDF-fixture');
  });
  tearDown(() async {
    await db.close();
    await file.parent.delete(recursive: true);
  });
  testWidgets('PDF review keeps original and attaches only after confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => context.push('/import'),
                  child: const Text('Import')))),
      GoRoute(
          path: '/import',
          builder: (_, state) => ImportTravelScreen(
              sharedPdf: {'path': file.path, 'name': 'Ticket.pdf'}))
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      tripPlanRepositoryProvider.overrideWithValue(repo),
      tripListProvider.overrideWith((ref) => Stream.value([trip])),
      travelApiProvider.overrideWithValue(api),
      travelRepositoryProvider.overrideWithValue(
          TravelRepository(db, null, RateRepository(db, null)))
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Museum'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Museum'), findsOneWidget);
    expect(api.uploads, 0);
    expect((await tester.runAsync(() => repo.watch(trip.id).first))!.items,
        isEmpty);
    final selector = find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<int> && w.decoration.labelText == 'Trip');
    await tester.scrollUntilVisible(selector, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tokyo · 2026-10-10').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Review details'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Review details'));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(api.uploads, 0);
    await tester.ensureVisible(find.text('Save item'));
    await tester.tap(find.text('Save item'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(plan.items.single['documentId'],
        'f78b0f4b-6643-4215-90eb-e050c871979b');
    expect(plan.items.single['time'], '11:00');
    expect(api.uploads, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    router.dispose();
  });
}
