import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:numi_app/config/theme.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
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
  Future<void> show(WidgetTester tester, Size size,
      {bool dark = false, double scale = 1}) async {
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
          travelRepositoryProvider.overrideWithValue(
              TravelRepository(db, null, RateRepository(db, null))),
          tripDetailProvider(trip.id).overrideWith((ref) => ref
              .watch(travelRepositoryProvider)
              .watchTripWithExpenses(trip.id)),
        ],
        child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark : AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: TripDetailScreen(tripId: trip.id)))));
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String name) async {
    final target = find.widgetWithText(Tab, name);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final prefix = Platform.environment['NUMI_PLANNER_SCREENSHOT'];
    if (prefix == null) return;
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => render.toImage(pixelRatio: 1)))!;
    final bytes = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    await tester.runAsync(() =>
        File('$prefix-$name.png').writeAsBytes(bytes!.buffer.asUint8List()));
    image.dispose();
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'two views and sheets preserve the selected day and existing features',
      (tester) async {
    await show(tester, const Size(390, 844));
    expect(find.byType(Tab), findsNWidgets(2));
    await capture(tester, 'phone-itinerary');
    await tapVisible(tester, find.byKey(const ValueKey('day-2026-10-02')));
    expect(find.text('Friday, 2 Oct'), findsOneWidget);
    await tab(tester, 'Saved places');
    await capture(tester, 'phone-places');
    await tapVisible(tester, find.byTooltip('Add place'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Nishiki Market');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('More details'));
    await capture(tester, 'phone-form');
    expect(find.text('Add links'), findsOneWidget);
    await tapVisible(tester, find.text('Save item'));
    expect(
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .ofKind('place')
            .length,
        2);
    await tab(tester, 'Itinerary');
    expect(find.text('Friday, 2 Oct'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('View bookings'));
    expect(find.text('Kyoto riverside hotel'), findsWidgets);
    await tapVisible(tester, find.text('Kyoto riverside hotel').last);
    expect(find.text('KYOTO-123'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Close panel').last);
    await tapVisible(tester, find.byTooltip('Close panel'));
    await tapVisible(tester, find.byTooltip('View preparation'));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .ofKind('task')
            .single['status'],
        'completed');
    await capture(tester, 'phone-preparation');
    await tapVisible(tester, find.byTooltip('Close panel'));
    await tapVisible(tester, find.byTooltip('View expenses'));
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.byTooltip('Add expense'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Close panel'));
    expect(find.text('Friday, 2 Oct'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('activity edits, moves and reordering remain persistent',
      (tester) async {
    final extra = PlanItem.create('activity')
        .copy({'title': 'Evening walk', 'date': '2026-10-01'});
    await repo.save(trip.id, extra);
    await show(tester, const Size(390, 1000));
    await tapVisible(tester, find.byTooltip('Reorder activities'));
    final handles = find.byType(ReorderableDragStartListener);
    final start = tester.getCenter(handles.last);
    final end = tester.getTopLeft(handles.first) - const Offset(0, 40);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 100));
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 10)!);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    var plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(plan.ofKind('activity').first.id, extra.id);
    expect(plan.ofKind('booking').length, 1);
    await tapVisible(tester, find.byTooltip('Finish reordering'));
    await tapVisible(tester, find.text('Evening walk'));
    await tapVisible(tester, find.text('Edit activity'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'River walk');
    tester.testTextInput.hide();
    await tapVisible(tester, find.text('Save item'));
    expect(find.text('River walk'), findsWidgets);
    await tapVisible(tester, find.byTooltip('Item actions'));
    await tapVisible(tester, find.text('Move to another day'));
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(plan.find(extra.id)!['date'], '2026-10-02');
    await tapVisible(tester, find.byTooltip('Item actions'));
    await tapVisible(tester, find.text('Leave unassigned'));
    await tapVisible(tester, find.byTooltip('Close panel'));
    expect(find.text('Friday, 2 Oct'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('day-')));
    expect(find.text('River walk'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('small screen and large text work in dark mode', (tester) async {
    await show(tester, const Size(320, 700), dark: true, scale: 1.5);
    await capture(tester, 'small-dark');
    await tab(tester, 'Saved places');
    await tapVisible(tester, find.textContaining('A very long cafe'));
    await tapVisible(tester, find.text('Edit place'));
    await tapVisible(tester, find.text('More details'));
    await tapVisible(tester, find.text('Save item'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'paid booking appears in expenses and either entry edits the same record',
      (tester) async {
    await show(tester, const Size(390, 844));
    await tapVisible(tester, find.byTooltip('View bookings'));
    await tapVisible(tester, find.text('Add booking'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'One-entry hotel');
    tester.testTextInput.hide();
    await tapVisible(tester, find.text('Stay duration'));
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final rangeFields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField));
    await tester.enterText(rangeFields.first, '10/01/2026');
    await tester.enterText(rangeFields.last, '10/03/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check-in 2026-10-01\nCheck-out 2026-10-03'),
        findsOneWidget);
    expect(find.textContaining('2 nights'), findsWidgets);
    await capture(tester, 'stay-duration');
    await tapVisible(tester,
        find.widgetWithText(TextFormField, 'Amount (optional until paid)'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (optional until paid)'),
        '420');
    tester.testTextInput.hide();
    await tapVisible(tester, find.byType(SwitchListTile));
    await capture(tester, 'payment-form');
    await tapVisible(tester, find.text('Save item'));
    var rows =
        (await tester.runAsync(() => db.tripDao.getExpensesForTrip(trip.id)))!;
    expect(rows.length, 1);
    expect(rows.single.amount, 420);
    final expenseId = rows.single.id;
    await tapVisible(tester, find.byTooltip('Close panel'));
    await tapVisible(tester, find.byTooltip('View expenses'));
    await tapVisible(tester, find.text('One-entry hotel').last);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Edit booking'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Updated once');
    tester.testTextInput.hide();
    await tapVisible(tester, find.text('Save item'));
    rows =
        (await tester.runAsync(() => db.tripDao.getExpensesForTrip(trip.id)))!;
    expect(rows.single.id, expenseId);
    expect(rows.single.name, 'Updated once');
    expect(
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .find(rows.single.planItemId!)!
            .title,
        'Updated once');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final kind in ['booking', 'activity']) {
    testWidgets(
        'existing expense can gain $kind details without re-entering its payment',
        (tester) async {
      await TravelRepository(db, null, RateRepository(db, null))
          .addTravelExpense(
              tripId: trip.id,
              amount: 90,
              currency: 'SGD',
              date: DateTime(2026, 9, 21),
              category: 'Other',
              name: 'Museum ticket');
      final original = (await db.tripDao.getExpensesForTrip(trip.id)).single;
      await show(tester, const Size(390, 844));
      await tapVisible(tester, find.byTooltip('View expenses'));
      await tapVisible(tester, find.text('Museum ticket'));
      await tapVisible(
          tester,
          find
              .text(kind == 'booking'
                  ? 'Add booking details'
                  : 'Add to itinerary')
              .last);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
      expect(find.text('New $kind'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Museum ticket'), findsWidgets);
      await tapVisible(tester, find.text('Save item'));
      final rows = (await tester
          .runAsync(() => db.tripDao.getExpensesForTrip(trip.id)))!;
      expect(rows.single.id, original.id);
      expect(rows.single.amount, 90);
      expect(rows.single.planItemId, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

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
    await tab(tester, 'Saved places');
    await tester.tap(find.textContaining('A very long cafe'));
    await tester.pumpAndSettle();
    expect(find.text('Menu'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Google Maps'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Baidu Maps'), findsOneWidget);
    await capture(tester, 'desktop-details');
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
