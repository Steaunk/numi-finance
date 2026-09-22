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
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).first);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200,
          scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'whole itinerary includes every day and undated transport after jumping',
      (tester) async {
    final flight = PlanItem.create('booking')
        .copy({'title': 'Undated connection', 'category': 'Flight'});
    await repo.save(trip.id, flight);
    await repo.save(
        trip.id,
        PlanItem.create('activity').copy(
            {'title': 'Last day walk', 'date': '2026-10-03', 'time': '15:00'}));
    await show(tester, const Size(390, 844));
    // Day selection scrolls; it never removes the other days or Anytime.
    expect(find.text('Thursday, 1 Oct'), findsOneWidget);
    expect(find.text('Saturday, 3 Oct'), findsOneWidget);
    expect(find.text('Undated connection'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('day-2026-10-03')));
    expect(find.text('Thursday, 1 Oct'), findsOneWidget);
    expect(find.text('Undated connection'), findsOneWidget);
    expect(find.text('Last day walk'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Saturday, 3 Oct')).dy, lessThan(700));
    await tapVisible(tester, find.text('Undated connection'));
    await tapVisible(tester, find.text('Edit booking'));
    await tapVisible(tester, find.text('Save item'));
    final saved = (await tester.runAsync(() => repo.watch(trip.id).first))!
        .find(flight.id)!;
    expect(saved['date'], '');
    expect(saved['endDate'], '');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'participants editor saves a specific traveller and filter keeps everyone arrangements',
      (tester) async {
    final me = PlanItem.create('person').copy({'title': 'Me'});
    final nyt = PlanItem.create('person').copy({'title': 'NYT'});
    await repo.save(trip.id, me);
    await repo.save(trip.id, nyt);
    await repo.save(
        trip.id,
        PlanItem.create('activity').copy(
            {'title': 'Solo museum', 'date': '2026-10-01'},
            participantIds: [nyt.id]));
    await show(tester, const Size(1100, 1200));
    final filter = find.byKey(const ValueKey('person-filter-'));
    await tapVisible(tester, filter);
    await tester.tap(find.text('Me').last);
    await tester.pumpAndSettle();
    expect(find.text('Solo museum'), findsNothing);
    expect(find.textContaining('A very long cafe name'), findsWidgets);
    await tapVisible(tester, find.byKey(ValueKey('person-filter-${me.id}')));
    await tester.tap(find.text('NYT').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Solo museum'));
    await tapVisible(tester, find.text('Edit activity'));
    expect(find.widgetWithText(CheckboxListTile, 'NYT'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(SwitchListTile, 'Everyone'));
    await tapVisible(tester, find.text('Save item'));
    final plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(
        plan.items.firstWhere((i) => i.title == 'Solo museum').participantIds,
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'three views and sheets preserve the selected day and existing features',
    (tester) async {
      await show(tester, const Size(390, 844));
      expect(find.byType(Tab), findsNWidgets(3));
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
      expect(find.text('Edit booking'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Close editor'));
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
      expect(find.text('Add expense'), findsOneWidget);
      await tab(tester, 'Itinerary');
      expect(find.text('Friday, 2 Oct'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('saved-place picker adds directly to the selected day', (
    tester,
  ) async {
    await show(tester, const Size(390, 844));
    await tapVisible(tester, find.byKey(const ValueKey('day-2026-10-02')));
    await tapVisible(tester, find.byKey(const ValueKey('add-day-2026-10-02')));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search saved places'),
      'coffee',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await capture(tester, 'saved-place-picker');
    await tapVisible(
      tester,
      find
          .text(
            'A very long cafe name for coffee, pastries and a slow afternoon',
          )
          .last,
    );
    final plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(
      plan.ofKind('activity').where((i) => i['date'] == '2026-10-02').length,
      1,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Friday, 2 Oct'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'spending retains city scope and a new expense needs no arrangement',
    (tester) async {
      final kyoto = PlanItem.create(
        'destination',
      ).copy({'title': 'Kyoto', 'date': '2026-10-01', 'endDate': '2026-10-03'});
      await repo.save(trip.id, kyoto);
      await show(tester, const Size(390, 844));
      await tapVisible(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Show destination',
        ),
      );
      await tester.tap(find.text('Kyoto').last);
      await tester.pumpAndSettle();
      await tab(tester, 'Spending');
      await tapVisible(tester, find.text('Add expense'));
      expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                  find.byKey(ValueKey('expense-city-${kyoto.id}')))
              .initialValue,
          kyoto.id);
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '5');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Water',
      );
      tester.testTextInput.hide();
      await tapVisible(tester, find.text('Add Expense'));
      final row = (await tester.runAsync(
        () => db.tripDao.getExpensesForTrip(trip.id),
      ))!
          .single;
      expect(row.destinationId, kyoto.id);
      expect(row.planItemId, isNull);
      expect(find.text('Water'), findsOneWidget);
      await capture(tester, 'standalone-city-spending');
      await tab(tester, 'Itinerary');
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Kyoto'),
        findsOneWidget,
      );
      await tab(tester, 'Spending');
      await tapVisible(tester, find.text('Water'));
      await tapVisible(tester,
          find.widgetWithText(DropdownButtonFormField<String>, 'Destination'));
      await tester.tap(find.text('Unassigned').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save Changes'));
      expect(find.text('Water'), findsOneWidget);
      expect(
          tester
              .widget<DropdownButtonFormField<String>>(find
                  .byKey(const ValueKey('destination-filter-__unassigned__')))
              .initialValue,
          '__unassigned__');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('activity edits, moves and reordering remain persistent',
      (tester) async {
    final extra = PlanItem.create('activity')
        .copy({'title': 'Evening walk', 'date': '2026-10-01'});
    await repo.save(trip.id, extra);
    await show(tester, const Size(390, 1000));
    final cafeActivity =
        (await tester.runAsync(() => repo.watch(trip.id).first))!
            .ofKind('activity')
            .first;
    await tester
        .runAsync(() => repo.save(trip.id, cafeActivity.copy({'time': ''})));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Reorder flexible activities'));
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
      'destinations can be added, reordered and selected without extra tabs',
      (tester) async {
    await show(tester, const Size(390, 844));
    await tapVisible(tester, find.text('Destinations'));
    for (final name in ['Tokyo', 'Kyoto']) {
      await tapVisible(tester, find.text('Add destination'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), name);
      tester.testTextInput.hide();
      expect(find.text('Visit dates'), findsOneWidget);
      await tapVisible(tester, find.text('Save item'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pumpAndSettle();
    }
    await tapVisible(tester, find.byTooltip('Move destination up').last);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
    final plan = (await tester.runAsync(() => repo.watch(trip.id).first))!;
    expect(plan.destinations.map((d) => d.title), ['Kyoto', 'Tokyo']);
    await capture(tester, 'destinations');
    await tapVisible(tester, find.byTooltip('Close panel'));
    expect(find.text('Kyoto → Tokyo'), findsOneWidget);
    await tapVisible(
        tester,
        find.widgetWithText(
            DropdownButtonFormField<String>, 'Show destination'));
    await tester.tap(find.text('Tokyo').last);
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('spending filters separate destination payments from transfers',
      (tester) async {
    await tester.runAsync(() async {
      final tokyo = PlanItem.create('destination').copy(
          {'title': 'Tokyo', 'date': '2026-10-01', 'endDate': '2026-10-02'});
      final kyoto = PlanItem.create('destination').copy(
          {'title': 'Kyoto', 'date': '2026-10-02', 'endDate': '2026-10-03'});
      await repo.save(trip.id, tokyo);
      await repo.save(trip.id, kyoto);
      final hotel = PlanItem.create('booking').copy({
        'title': 'Kyoto paid hotel',
        'date': '2026-10-02',
        'endDate': '2026-10-03',
        'destinationId': kyoto.id,
        'amount': '200',
        'currency': 'SGD',
        'paymentStatus': 'paid',
        'paidDate': '2026-09-21'
      });
      await repo.save(trip.id, hotel);
      await repo.save(
          trip.id,
          PlanItem.create('booking').copy({
            'title': 'Intercity train',
            'category': 'Train',
            'date': '2026-10-02',
            'destinationId': tokyo.id,
            'endDestinationId': kyoto.id,
            'amount': '50',
            'currency': 'SGD',
            'paymentStatus': 'paid',
            'paidDate': '2026-09-21'
          }));
    });
    await show(tester, const Size(390, 844));
    await tapVisible(tester, find.byTooltip('View expenses'));
    await tapVisible(
        tester,
        find.widgetWithText(
            DropdownButtonFormField<String>, 'Show destination'));
    await tester.tap(find.text('Kyoto').last);
    await tester.pumpAndSettle();
    expect(find.text('Kyoto paid hotel'), findsOneWidget);
    expect(find.text('Intercity train'), findsNothing);
    await capture(tester, 'destination-spending');
    await tapVisible(
        tester,
        find.widgetWithText(
            DropdownButtonFormField<String>, 'Show destination'));
    await tester.tap(find.text('Between destinations').last);
    await tester.pumpAndSettle();
    expect(find.text('Intercity train'), findsOneWidget);
    expect(find.text('Kyoto paid hotel'), findsNothing);
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
    await tapVisible(tester, find.text('Payment (optional)'));
    await tapVisible(tester,
        find.widgetWithText(TextFormField, 'Amount (optional until paid)'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount (optional until paid)'),
        '420');
    tester.testTextInput.hide();
    await tapVisible(tester, find.widgetWithText(SwitchListTile, 'Paid'));
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
    expect(rows.single.name, 'One-entry hotel');
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
