import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:go_router/go_router.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/remote/api_client.dart';
import 'package:numi_app/data/remote/endpoints/travel_api.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/travel/screens/import_travel_screen.dart';

class PreviewApi extends TravelApi {
  final bool multi;
  PreviewApi({this.multi = false}) : super(ApiClient('https://example.test'));
  @override
  Future<Map<String, dynamic>> previewShare(String text, String url) async {
    final stay = <String, dynamic>{
      'title': 'Kamakura Prince Hotel',
      'category': 'Accommodation',
      'date': '2026-10-07',
      'endDate': '2026-10-09',
      'source': 'Trip.com',
      'notes': text,
      'links': [
        {'url': url, 'purpose': 'Booking'}
      ],
    };
    return multi
        ? {
            'items': [
              stay,
              {
                'kind': 'booking',
                'title': 'Flight SQ637',
                'category': 'Flight',
                'date': '2026-10-12',
                'endDate': '2026-10-12',
                'time': '11:10',
                'endTime': '17:20',
                'address': 'NRT',
                'endAddress': 'SIN',
                'source': 'Trip.com',
                'links': [
                  {'url': url, 'purpose': 'Booking'}
                ],
              }
            ]
          }
        : stay;
  }
}

void main() {
  late AppDatabase db;
  late TripPlanRepository repo;
  late Trip trip;
  late int id;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TripPlanRepository(db, null);
    id = await db.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 6),
        endDate: DateTime(2026, 10, 12)));
    trip = Trip(
        id: id,
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 6),
        endDate: DateTime(2026, 10, 12));
  });
  tearDown(() async => db.close());

  for (final multi in [false, true]) {
    testWidgets(
        'shared link requires review and saves all segments (multi=$multi)',
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
                    child: const Text('Open import')))),
        GoRoute(
            path: '/import',
            builder: (_, state) => const ImportTravelScreen(
                sharedText:
                    'https://www.trip.com/hotels/kamakura-prince-hotel/')),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: [
        tripListProvider.overrideWith((ref) => Stream.value([trip])),
        tripPlanRepositoryProvider.overrideWithValue(repo),
        travelApiProvider.overrideWithValue(PreviewApi(multi: multi)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open import'));
      await tester.pumpAndSettle();
      expect(find.text('Kamakura Prince Hotel'), findsOneWidget);
      expect(
          (await tester.runAsync(() => repo.watch(id).first))!.items, isEmpty);
      final review = find.text('Review details');
      await tester.scrollUntilVisible(review, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                  of: review, matching: find.byType(FilledButton)))
              .onPressed,
          isNull);
      final selector = find.byWidgetPredicate((w) =>
          w is DropdownButtonFormField<int> &&
          w.decoration.labelText == 'Trip');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tokyo · 2026-10-06').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(review, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(review);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(
          (await tester.runAsync(() => repo.watch(id).first))!.items, isEmpty);
      final title = find.widgetWithText(TextFormField, 'Kamakura Prince Hotel');
      await tester.enterText(title, 'Our Kamakura hotel');
      final save = find.text('Save item');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      final plan = (await tester.runAsync(() => repo.watch(id).first))!;
      expect(plan.items, hasLength(1));
      expect(plan.items.single.title, 'Our Kamakura hotel');
      expect(plan.items.single['date'], '2026-10-07');
      expect(plan.items.single['status'], 'planned');
      expect(plan.items.single['paymentStatus'], 'unpaid');
      expect(plan.items.single.participantIds, isEmpty);
      if (multi) {
        expect(find.text('Flight SQ637'), findsOneWidget);
        await tester.ensureVisible(find.text('Review details'));
        await tester.tap(find.text('Review details'));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save item'));
        await tester.tap(find.text('Save item'));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        final updated = (await tester.runAsync(() => repo.watch(id).first))!;
        expect(updated.items, hasLength(2));
        expect(updated.items.last['category'], 'Flight');
        expect(updated.items.last['time'], '11:10');
        expect(updated.items.last['endAddress'], 'SIN');
      }
      expect(find.text('Open import'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      router.dispose();
    });
  }
}
