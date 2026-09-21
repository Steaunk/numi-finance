import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/models/trip.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/providers/providers.dart';
import 'package:numi_app/ui/travel/screens/trip_detail_screen.dart';
import 'package:numi_app/ui/travel/widgets/plan_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late TripPlanRepository repo;
  late Trip trip;
  late SharedPreferences prefs;
  final boundary = GlobalKey();
  setUpAll(() async {
    if (Platform.environment['NUMI_PLANNER_FONT_DIR']
        case final String folder) {
      for (final entry in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf'
      }.entries) {
        final bytes = await File('$folder/${entry.value}').readAsBytes();
        await (FontLoader(entry.key)
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = TripPlanRepository(db, null);
    final id = await db.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Kyoto autumn escape',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3)));
    trip = Trip(
        id: id,
        destination: 'Kyoto autumn escape',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3));
    final cafe = PlanItem.create('place').copy({
      'title':
          'A very long cafe name for coffee, pastries and a slow afternoon',
      'category': 'Cafe',
      'address': 'Higashiyama, Kyoto',
      'priority': 'Must go'
    }, links: [
      const PlanLink(url: 'https://maps.app.goo.gl/kyoto', purpose: 'Map'),
      const PlanLink(
          url: 'https://example.com/menu', purpose: 'Website', label: 'Menu')
    ]);
    await repo.save(id, cafe);
    await repo.save(
        id,
        PlanItem.create('activity')
            .copy({'placeId': cafe.id, 'date': '2026-10-01', 'time': '10:00'}));
    await repo.save(
        id,
        PlanItem.create('booking').copy({
          'title': 'Kyoto riverside hotel',
          'date': '2026-10-01',
          'endDate': '2026-10-03',
          'status': 'confirmed',
          'confirmation': 'KYOTO-123'
        }));
    await repo.save(
        id,
        PlanItem.create('task')
            .copy({'title': 'Pack chargers', 'category': 'Packing'}));
  });
  tearDown(() async => db.close());
  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          tripPlanRepositoryProvider.overrideWithValue(repo),
          sharedPrefsProvider.overrideWithValue(prefs),
          serverUrlProvider.overrideWith((ref) => ''),
          displayCurrencyProvider.overrideWith((ref) => 'SGD'),
          tripDetailProvider(trip.id).overrideWith((ref) => Stream.value(trip)),
        ],
        child: MaterialApp(
            home: RepaintBoundary(
                key: boundary, child: TripDetailScreen(tripId: trip.id)))));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    final target = find.widgetWithText(Tab, name);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'phone flows preserve expenses and support places, itinerary, bookings and tasks',
      (tester) async {
    await show(tester, const Size(390, 844));
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Accommodation gaps'), findsNothing);
    await tab(tester, 'Places');
    expect(find.textContaining('A very long cafe'), findsOneWidget);
    await tester.tap(find.byTooltip('Add place'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Nishiki Market');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save item'));
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    final savedPlan = await tester.runAsync(() => repo.watch(trip.id).first);
    expect(savedPlan!.ofKind('place').length, 2);
    await tab(tester, 'Itinerary');
    expect(find.text('Activities'), findsOneWidget);
    await tab(tester, 'Bookings');
    expect(find.text('Kyoto riverside hotel'), findsOneWidget);
    await tab(tester, 'Preparation');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .ofKind('task')
            .single['status'],
        'completed');
    await tab(tester, 'Expenses');
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.byTooltip('Add expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'external link failure keeps the page and offers a working copy fallback',
      (tester) async {
    String? copied;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (_) async => false);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null));
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: PlanLinks(links: [
      PlanLink(url: 'https://example.com/menu', label: 'Restaurant menu')
    ]))));
    // The system cannot find a handler for this valid URL.
    await tester.tap(find.text('Restaurant menu'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open link'), findsOneWidget);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://example.com/menu');
    expect(find.text('Could not open link'), findsNothing);
    expect(find.text('Restaurant menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved links can be renamed, changed and removed independently',
      (tester) async {
    var links = const [
      PlanLink(url: 'https://example.com/old', label: 'Old menu'),
      PlanLink(url: 'https://maps.app.goo.gl/location', label: 'Directions'),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      return PlanLinksEditor(
          links: links, onChanged: (value) => setState(() => links = value));
    }))));
    await tester.tap(find.text('Old menu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'URL or share text'),
        'https://example.com/new');
    await tester.enterText(
        find.widgetWithText(TextField, 'Display name (optional)'), 'New menu');
    await tester.tap(find.text('Save links'));
    await tester.pumpAndSettle();
    expect(links.first.url, 'https://example.com/new');
    expect(find.text('New menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove link').first);
    await tester.pumpAndSettle();
    expect(links.single.label, 'Directions');
    expect(find.text('New menu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'desktop renders expanded links and supports imported share links',
      (tester) async {
    await show(tester, const Size(1100, 900));
    await tab(tester, 'Places');
    await tester.tap(find.textContaining('A very long cafe'));
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Google Maps'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Baidu Maps'), findsOneWidget);
    // Optional visual QA artifact; never writes a golden into the repository.
    if (Platform.environment['NUMI_PLANNER_SCREENSHOT']
        case final String path) {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image =
          (await tester.runAsync(() => render.toImage(pixelRatio: 1)))!;
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      await tester
          .runAsync(() => File(path).writeAsBytes(bytes!.buffer.asUint8List()));
      image.dispose();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      return PlanLinksEditor(
          links: const [],
          onChanged: (links) {
            expect(links.length, 2);
          });
    }))));
    await tester.tap(find.text('Add links'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'URL or share text'),
        'Cafe https://maps.app.goo.gl/abc。 Guide https://xhslink.com/xyz');
    await tester.pumpAndSettle();
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Xiaohongshu'), findsOneWidget);
    await tester.tap(find.text('Save links'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
