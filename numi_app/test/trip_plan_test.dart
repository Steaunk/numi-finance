import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/remote/endpoints/travel_api.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
import 'package:numi_app/models/trip_plan.dart';

class PlanApiFake implements TravelApi {
  Map<String, dynamic> content = {'items': []};
  int revision = 0;
  String? mutation;
  int puts = 0;
  bool offline = false;
  bool loseResponse = false;
  Future<void> Function()? beforePut;
  Future<void> Function()? beforeGet;
  final trips = <int, Map<String, dynamic>>{};
  int nextTripId = 1;
  DioException error(int? status) => DioException(
      requestOptions: RequestOptions(path: '/plan'),
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/plan'),
              statusCode: status));
  @override
  Future<Map<String, dynamic>> getPlan(int id) async {
    if (offline) throw error(null);
    await beforeGet?.call();
    return {'content': content, 'revision': revision};
  }

  @override
  Future<Map<String, dynamic>> putPlan(int id, Map<String, dynamic> p) async {
    puts++;
    if (offline) throw error(null);
    await beforePut?.call();
    if (p['mutation_id'] != mutation) {
      if (p['conflict_choice'] != null) {
        if (p['expected_revision'] != revision) throw error(409);
      } else if (p['revision'] != revision) {
        throw error(409);
      }
      revision++;
      if (p['conflict_choice'] != 'server') {
        content = Map<String, dynamic>.from(p['content'] as Map);
      }
      mutation = p['mutation_id'] as String;
    }
    if (loseResponse) {
      loseResponse = false;
      throw error(null);
    }
    return {'content': content, 'revision': revision};
  }

  @override
  Future<Map<String, dynamic>> addTrip(Map<String, dynamic> p) async {
    if (offline) throw error(null);
    final existing =
        trips.values.where((t) => t['client_id'] == p['client_id']).firstOrNull;
    if (existing != null) return existing;
    final row = {...p, 'id': nextTripId++};
    trips[row['id'] as int] = row;
    if (loseResponse) {
      loseResponse = false;
      throw error(null);
    }
    return row;
  }

  @override
  Future<void> deleteTrip(int id) async {
    if (offline) throw error(null);
    trips.remove(id);
  }

  @override
  Future<void> deleteTripByClient(String clientId) async {
    if (offline) throw error(null);
    trips.removeWhere((id, t) => t['client_id'] == clientId);
  }

  @override
  Future<List<Map<String, dynamic>>> getTrips({String currency = 'SGD'}) async {
    if (offline) throw error(null);
    return trips.values.toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getTripExpenses(int tripId,
          {String currency = 'SGD'}) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  var dbClosed = false;
  late int id;
  late PlanApiFake api;
  final start = DateTime(2026, 10, 1);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dbClosed = false;
    api = PlanApiFake();
    id = await db.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Tokyo',
        startDate: start,
        endDate: DateTime(2026, 10, 3),
        remoteId: const Value(10),
        synced: const Value(true)));
  });
  tearDown(() async {
    if (!dbClosed) await db.close();
  });
  Future<TripPlan> read(TripPlanRepository repo) => repo.watch(id).first;
  PlanItem place(String title) =>
      PlanItem.create('place').copy({'title': title});

  test(
      'offline edits persist, reorder, and unlink deleted place without dropping activity',
      () async {
    final repo = TripPlanRepository(db, null);
    final p = place('Cafe');
    await repo.save(id, p);
    final a = PlanItem.create('activity')
        .copy({'placeId': p.id, 'date': '2026-10-01'});
    final b = PlanItem.create('activity').copy({'title': 'Rest'});
    await repo.save(id, a);
    await repo.save(id, b);
    await repo.reorder(id, [b.id, a.id]);
    expect(
        (await read(repo)).ofKind('activity').map((i) => i.id), [b.id, a.id]);
    await repo.remove(id, p.id);
    final plan = await read(repo);
    expect(plan.find(a.id)!['placeId'], '');
    expect(plan.find(a.id)!.title, 'Cafe');
    expect(plan.pending, true);
  });

  test(
      'successful sync drains edits made while an earlier request is in flight',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    api.beforePut = () async {
      if (!entered.isCompleted) {
        entered.complete();
        await release.future;
      }
    };
    final repo = TripPlanRepository(db, api);
    final p = place('Old');
    await repo.save(id, p);
    await entered.future;
    await repo.save(id, p.copy({'title': 'New'}));
    release.complete();
    await repo.sync(id);
    expect((api.content['items'] as List).single['title'], 'New');
    expect((await read(repo)).pending, false);
    expect(api.puts, 2);
  });

  test('edits during a pull are preserved and uploaded before sync completes',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    api.beforeGet = () async {
      if (!entered.isCompleted) {
        entered.complete();
        await release.future;
      }
    };
    final repo = TripPlanRepository(db, api);
    final syncing = repo.sync(id);
    await entered.future;
    await repo.save(id, place('Saved during pull'));
    release.complete();
    await syncing;
    expect((api.content['items'] as List).single['title'], 'Saved during pull');
    expect((await read(repo)).pending, false);
  });

  test('timeout after commit retries same mutation without duplicate revision',
      () async {
    api.loseResponse = true;
    final repo = TripPlanRepository(db, api);
    await repo.save(id, place('Cafe'));
    await repo.sync(id);
    expect((await read(repo)).pending, true);
    expect(api.revision, 1);
    await repo.sync(id);
    expect((await read(repo)).pending, false);
    expect(api.revision, 1);
  });

  test('conflict preserves local changes until explicit resolution', () async {
    api.revision = 4;
    api.content = {
      'items': [place('Server').toJson()]
    };
    final repo = TripPlanRepository(db, api);
    await repo.save(id, place('Local'));
    await repo.sync(id);
    expect((await read(repo)).error, 'conflict');
    expect((await read(repo)).items.single.title, 'Local');
    final before = api.puts;
    await repo.sync(id);
    expect(api.puts, before);
    await repo.resolve(id, keepLocal: true);
    expect((await read(repo)).error, '');
    expect((api.content['items'] as List).single['title'], 'Local');
    api.revision++;
    api.content = {
      'items': [place('Remote edit').toJson()]
    };
    await repo.save(id, place('Another local'));
    await repo.sync(id);
    await repo.resolve(id, keepLocal: false);
    expect((await read(repo)).items.single.title, 'Remote edit');
    expect((await read(repo)).pending, false);
  });

  test('no server and unavailable backend keep records recoverable', () async {
    final offline = TripPlanRepository(db, null);
    await offline.save(id, place('Saved'));
    api.offline = true;
    final repo = TripPlanRepository(db, api);
    await repo.sync(id);
    expect((await read(repo)).items.single.title, 'Saved');
    expect((await read(repo)).pending, true);
    expect((await read(repo)).error, isNotEmpty);
    api.offline = false;
    await repo.sync(id);
    expect((await read(repo)).pending, false);
  });

  test('planner waits for unsynced parent and sends it before the document',
      () async {
    final trips = TravelRepository(db, null, RateRepository(db, null));
    await trips.addTrip(destination: 'Kyoto', startDate: start, endDate: start);
    final local = (await db.tripDao.getAllTrips())
        .firstWhere((t) => t.destination == 'Kyoto');
    final offline = TripPlanRepository(db, null);
    await offline.save(local.id, place('Tea'));
    final onlineTrips = TravelRepository(db, api, RateRepository(db, null));
    final planner =
        TripPlanRepository(db, api, prepareTrip: onlineTrips.flushTrips);
    await planner.sync(local.id);
    expect((await db.tripDao.getById(local.id))!.remoteId, isNotNull);
    expect((api.content['items'] as List).single['title'], 'Tea');
  });

  test(
      'delete trip cleans planning and expenses and cannot be resurrected by pull',
      () async {
    api.trips[10] = {
      'id': 10,
      'destination': 'Tokyo',
      'start_date': '2026-10-01',
      'end_date': '2026-10-03',
      'notes': ''
    };
    final planner = TripPlanRepository(db, null);
    await planner.save(id, place('Cafe'));
    await db.tripDao.insertTravelExpense(TravelExpensesCompanion.insert(
        tripId: id,
        amount: 5,
        currency: 'USD',
        date: start,
        category: 'Shopping',
        name: 'Book'));
    final trips = TravelRepository(db, api, RateRepository(db, null));
    api.offline = true;
    await trips.deleteTrip(id);
    await trips.flushTrips();
    expect(await db.select(db.tripPlans).get(), isEmpty);
    expect(await db.select(db.travelExpenses).get(), isEmpty);
    expect((await db.syncQueueDao.getPending()).single.operation, 'delete');
    api.offline = false;
    await trips.syncFromServer('USD');
    await trips.syncFromServer('USD');
    expect(await db.tripDao.getById(id), isNull);
    expect(api.trips, isEmpty);
  });

  test('deleting a trip during plan upload cannot recreate its local document',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    api.beforePut = () async {
      entered.complete();
      await release.future;
    };
    final planner = TripPlanRepository(db, api);
    await planner.save(id, place('Cafe'));
    await entered.future;
    await TravelRepository(db, null, RateRepository(db, null)).deleteTrip(id);
    release.complete();
    await planner.sync(id);
    expect(await db.tripDao.getById(id), isNull);
    expect(await db.select(db.tripPlans).get(), isEmpty);
  });

  test(
      'delete after lost parent create response removes the committed remote trip',
      () async {
    final trips = TravelRepository(db, api, RateRepository(db, null));
    api.loseResponse = true;
    await trips.addTrip(
        destination: 'Lost response', startDate: start, endDate: start);
    // Wait for the internally scheduled create to fail, without triggering another upload.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final row = (await db.tripDao.getAllTrips())
        .firstWhere((t) => t.destination == 'Lost response');
    expect(row.remoteId, isNull);
    expect(api.trips, isNotEmpty);
    await trips.deleteTrip(row.id);
    await trips.flushTrips();
    expect(api.trips, isEmpty);
    expect(
        (await db.syncQueueDao.getPending()).where((q) => q.localId == row.id),
        isEmpty);
  });

  PlanItem paidBooking({String? clientId}) => PlanItem.create('booking').copy({
        'title': 'Hotel',
        'date': '2026-10-01',
        'endDate': '2026-10-03',
        'amount': '200',
        'currency': 'SGD',
        'paymentStatus': 'paid',
        'paidDate': '2026-09-21',
        if (clientId != null) 'expenseClientId': clientId,
      });

  test(
      'paid booking is one expense, editing updates it and cancellation keeps it',
      () async {
    final repo = TripPlanRepository(db, null);
    final booking = paidBooking();
    await repo.save(id, booking);
    final stored = (await read(repo)).find(booking.id)!;
    final first = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(first.planItemId, booking.id);
    expect(first.amount, 200);
    expect(first.date, DateTime(2026, 9, 21));
    await repo.save(
        id, stored.copy({'title': 'Updated hotel', 'amount': '240'}));
    final edited = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(edited.id, first.id);
    expect(edited.name, 'Hotel');
    expect(edited.amount, 240);
    await repo.save(id, stored.copy({'status': 'cancelled'}));
    expect((await db.tripDao.getExpensesForTrip(id)).length, 1);
    await repo.remove(id, booking.id);
    final detached = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(detached.planItemId, isNull);
    expect(detached.clientId, first.clientId);
    expect((await db.syncQueueDao.getPending()).single.entityType,
        'travel_expense');
  });

  test(
      'unpaid booking is excluded until paid and removing payment keeps booking',
      () async {
    final repo = TripPlanRepository(db, null);
    final booking = paidBooking().copy({'paymentStatus': 'unpaid'});
    await repo.save(id, booking);
    expect(await db.tripDao.getExpensesForTrip(id), isEmpty);
    await repo.save(id, booking.copy({'paymentStatus': 'paid'}));
    expect((await db.tripDao.getExpensesForTrip(id)).length, 1);
    await repo.removePayment(id, booking.id);
    expect(await db.tripDao.getExpensesForTrip(id), isEmpty);
    expect((await read(repo)).find(booking.id)!['paymentStatus'], 'unpaid');
  });

  test(
      'existing offline expense becomes booking with same row and no queued duplicate',
      () async {
    final travel = TravelRepository(db, null, RateRepository(db, null));
    await travel.addTravelExpense(
        tripId: id,
        amount: 300,
        currency: 'SGD',
        date: DateTime(2026, 9, 1),
        category: 'Accommodation',
        name: 'Already paid');
    final original = (await db.tripDao.getExpensesForTrip(id)).single;
    final repo = TripPlanRepository(db, null);
    final booking = await repo.itemFromExpense(id, original.id);
    expect(booking['amount'], '300.0');
    expect(booking['paidDate'], '2026-09-01');
    await repo.save(id, booking);
    final linked = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(linked.id, original.id);
    expect(linked.clientId, original.clientId);
    expect(
        (await db.syncQueueDao.getPending())
            .where((q) => q.entityType == 'travel_expense'),
        isEmpty);
    await repo.save(id, booking);
    expect((await db.tripDao.getExpensesForTrip(id)).length, 1);
  });

  test(
      'legacy remote identity adopts a refreshed server expense without copying',
      () async {
    final travel = TravelRepository(db, null, RateRepository(db, null));
    await travel.addTravelExpense(
        tripId: id,
        amount: 300,
        currency: 'SGD',
        date: DateTime(2026, 9, 1),
        category: 'Transportation',
        name: 'Flight');
    final original = (await db.tripDao.getExpensesForTrip(id)).single;
    await db.tripDao.updateTravelExpenseRow(
        original.id,
        const TravelExpensesCompanion(
            remoteId: Value(78), clientId: Value('server-uuid')));
    final repo = TripPlanRepository(db, null);
    await repo.save(
        id, paidBooking(clientId: 'remote-78').copy({'category': 'Flight'}));
    final row = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(row.id, original.id);
    expect(row.remoteId, 78);
    expect(row.category, 'Transportation');
    expect(row.amount, 200);
  });

  test(
      'multiple destinations preserve route, inherited places, transfers and payments',
      () async {
    final repo = TripPlanRepository(db, null);
    final tokyo = PlanItem.create('destination').copy(
        {'title': 'Tokyo', 'date': '2026-10-01', 'endDate': '2026-10-02'});
    final kyoto = PlanItem.create('destination').copy(
        {'title': 'Kyoto', 'date': '2026-10-02', 'endDate': '2026-10-03'});
    await repo.save(id, tokyo);
    await repo.save(id, kyoto);
    final sight = place('Temple').copy({'destinationId': kyoto.id});
    await repo.save(id, sight);
    final visit = paidBooking()
        .copy({'kind': 'activity', 'title': '', 'placeId': sight.id});
    await repo.save(id, visit);
    final rail = paidBooking().copy({
      'title': 'Train',
      'category': 'Train',
      'destinationId': tokyo.id,
      'endDestinationId': kyoto.id
    });
    await repo.save(id, rail);
    var plan = await read(repo);
    expect(plan.destinationsOn('2026-10-02').length, 2);
    expect(plan.destinationIdFor(visit), kyoto.id);
    expect(plan.expenseDestination(visit.id), kyoto.id);
    expect(plan.expenseDestination(rail.id), '__transfers__');
    expect(plan.matchesDestination(rail, tokyo.id), true);
    expect(plan.matchesDestination(rail, kyoto.id), true);
    expect(plan.expenseDestination(null), '');
    await repo.reorder(id, [kyoto.id, tokyo.id]);
    plan = await read(TripPlanRepository(db, null));
    expect(plan.destinations.map((d) => d.id), [kyoto.id, tokyo.id]);
    await repo.remove(id, sight.id);
    plan = await read(repo);
    expect(plan.destinationIdFor(plan.find(visit.id)!), kyoto.id);
    expect(plan.find(visit.id)!.title, 'Temple');
    await repo.remove(id, kyoto.id);
    plan = await read(repo);
    expect(plan.find(visit.id), isNotNull);
    expect(plan.destinationIdFor(plan.find(visit.id)!), '');
    expect(plan.find(rail.id)!['endDestinationId'], '');
    expect((await db.tripDao.getExpensesForTrip(id)).length, 2);
    await expectLater(
        repo.save(id, place('Dangling').copy({'destinationId': kyoto.id})),
        throwsStateError);
  });

  test('conflict server choice removes discarded local payment', () async {
    api.revision = 1;
    final repo = TripPlanRepository(db, api);
    await repo.save(id, paidBooking());
    await repo.sync(id);
    expect((await read(repo)).error, 'conflict');
    expect((await db.tripDao.getExpensesForTrip(id)).length, 1);
    await repo.resolve(id, keepLocal: false);
    expect(await db.tripDao.getExpensesForTrip(id), isEmpty);
  });

  test('payment changes during upload retain newest amount and one ledger row',
      () async {
    final entered = Completer<void>(), release = Completer<void>();
    api.beforePut = () async {
      if (!entered.isCompleted) {
        entered.complete();
        await release.future;
      }
    };
    final repo = TripPlanRepository(db, api);
    final booking = paidBooking();
    await repo.save(id, booking);
    await entered.future;
    final saved = (await read(repo)).find(booking.id)!;
    await repo.save(id, saved.copy({'amount': '500'}));
    release.complete();
    await repo.sync(id);
    expect((await db.tripDao.getExpensesForTrip(id)).single.amount, 500);
    expect((api.content['items'] as List).single['amount'], '500');
  });

  test(
      'flight and saved sight payments derive categories and keep shared titles',
      () async {
    final repo = TripPlanRepository(db, null);
    final flight = paidBooking().copy({'category': 'Flight'});
    final museum = place('Museum').copy({'category': 'Sightseeing'});
    await repo.save(id, flight);
    await repo.save(id, museum);
    final visit = PlanItem.create('activity').copy({
      'placeId': museum.id,
      'date': '2026-10-01',
      'paymentStatus': 'paid',
      'amount': '30',
      'currency': 'SGD',
      'paidDate': '2026-09-21'
    });
    await repo.save(id, visit);
    var rows = await db.tripDao.getExpensesForTrip(id);
    expect(rows.firstWhere((e) => e.planItemId == flight.id).category,
        'Transportation');
    expect(rows.firstWhere((e) => e.planItemId == visit.id).category,
        'Sightseeing');
    await repo.save(id, museum.copy({'title': 'Art Museum'}));
    rows = await db.tripDao.getExpensesForTrip(id);
    expect(rows.firstWhere((e) => e.planItemId == visit.id).name, 'Museum');
    await repo.remove(id, museum.id);
    expect(
        (await db.tripDao.getExpensesForTrip(id))
            .firstWhere((e) => e.planItemId == visit.id)
            .name,
        'Museum');
  });

  test('map and multi-link sharing validate without platform APIs', () {
    final urls = extractPlanLinks(
        'Try this 咖啡 https://maps.app.goo.gl/abc。\nAnd https://booking.com/hotel?a=1&b=2');
    expect(urls.length, 2);
    expect(linkPlatform(urls.first), 'Google Maps');
    expect(linkPlatform('https://evilbooking.com/x'), 'evilbooking.com');
    expect(safeExternalLink('javascript:alert(1)'), isNull);
    expect(safeExternalLink('https://user:pass@example.com'), isNull);
    expect(safeExternalLink('https://example.com:99999'), isNull);
    expect(mapSearchLink('茶 & Coffee', '京都').queryParameters['query'],
        '茶 & Coffee 京都');
    final baidu = baiduMapSearchLink('茶 & Coffee', '南京西路 1 号', '上海');
    expect(baidu.scheme, 'https');
    expect(baidu.queryParameters['query'], '茶 & Coffee 南京西路 1 号');
    expect(baidu.queryParameters['region'], '上海');
    expect(linkPlatform(baidu.toString()), 'Baidu Maps');
    final p = place('Cafe').copy({}, links: [
      PlanLink(url: urls.first),
      PlanLink(url: urls.last, purpose: 'Booking')
    ]);
    expect(
        TripPlan.decode(TripPlan(items: [p]).encode())
            .items
            .single
            .links
            .length,
        2);
  });

  test(
    'stay coverage excludes checkout, ignores cancelled and supports overnight transit',
    () {
      final stay = PlanItem.create('booking').copy(
          {'title': 'Hotel', 'date': '2026-10-01', 'endDate': '2026-10-03'});
      final noStay = PlanItem.create('booking').copy({
        'title': 'Night train',
        'category': 'No accommodation needed',
        'date': '2026-10-03'
      });
      expect(stay.stayNights, 2);
      expect(stay.stayDuration, '2 nights');
      expect(stay.copy({'endDate': '2026-10-02'}).stayDuration, '1 night');
      expect(stay.copy({'endDate': '2026-10-01'}).stayNights, isNull);
      expect(
          stay.copy({'date': '2026-10-31', 'endDate': '2026-11-02'}).stayNights,
          2);
      expect(TripPlan(items: [stay]).hasStay('2026-10-02'), true);
      expect(TripPlan(items: [stay]).hasStay('2026-10-03'), false);
      expect(
          TripPlan(items: [
            stay.copy({'status': 'cancelled'})
          ]).hasStay('2026-10-02'),
          false);
      expect(TripPlan(items: [noStay]).hasStay('2026-10-03'), true);
      expect(tripDays(start, start).length, 1);
      expect(tripPhase(start, start, DateTime(2026, 10, 1, 23)), 'Travelling');
    },
  );

  test('timeline sorts every timed arrangement and keeps flexible order', () {
    PlanItem activity(String name, String time) => PlanItem.create(
          'activity',
        ).copy({'title': name, 'date': '2026-10-01', 'time': time});
    final dinner = activity('Dinner', '18:00');
    final breakfast = activity('Breakfast', '09:00');
    final walk = activity('Walk', '');
    final shopping = activity('Shopping', '');
    final booking = PlanItem.create('booking').copy({
      'title': 'Lunch reservation',
      'category': 'Reservation',
      'date': '2026-10-01',
      'time': '12:00',
    });
    final plan = TripPlan(items: [dinner, walk, breakfast, shopping, booking]);
    expect(plan.timelineOn('2026-10-01').map((i) => i.title), [
      'Breakfast',
      'Lunch reservation',
      'Dinner',
      'Walk',
      'Shopping',
    ]);
  });

  test(
    'standalone city spending persists without creating an itinerary item',
    () async {
      final city = PlanItem.create(
        'destination',
      ).copy({'title': 'Kyoto', 'date': '2026-10-01', 'endDate': '2026-10-03'});
      final localPlanner = TripPlanRepository(db, null);
      await localPlanner.save(id, city);
      final travel = TravelRepository(db, null, RateRepository(db, null));
      await travel.addTravelExpense(
        tripId: id,
        amount: 5,
        currency: 'SGD',
        date: start,
        category: 'Other',
        name: 'Water',
        destinationId: city.id,
      );
      final expense = (await travel.getTripWithExpenses(id))!.expenses.single;
      var plan = await localPlanner.watch(id).first;
      expect(expense.planItemId, isNull);
      expect(plan.items.length, 1);
      expect(
        plan.expenseDestination(
          expense.planItemId,
          destinationId: expense.destinationId,
        ),
        city.id,
      );
      final enriched = await localPlanner.itemFromExpense(
        id,
        expense.id,
        kind: 'activity',
      );
      expect(enriched['destinationId'], city.id);
      await localPlanner.remove(id, city.id);
      final kept = (await travel.getTripWithExpenses(id))!.expenses.single;
      expect(kept.id, expense.id);
      expect(kept.amount, 5);
      expect(kept.destinationId, '');
      expect(kept.planItemId, isNull);
    },
  );

  test(
    'schema 4 upgrade preserves standalone expenses and adds destination storage',
    () async {
      await db.close();
      dbClosed = true;
      final dir = await Directory.systemTemp.createTemp('numi-city-migration');
      final file = File('${dir.path}/test.sqlite');
      var store = AppDatabase(NativeDatabase(file));
      final tripId = await store.tripDao.insertTrip(
        TripsCompanion.insert(
          destination: 'Existing',
          startDate: start,
          endDate: start,
        ),
      );
      final expenseId = await store.tripDao.insertTravelExpense(
        TravelExpensesCompanion.insert(
          tripId: tripId,
          amount: 5,
          currency: 'SGD',
          date: start,
          category: 'Other',
          name: 'Water',
        ),
      );
      await store.customStatement(
        'ALTER TABLE travel_expenses DROP COLUMN destination_id',
      );
      await store.customStatement('PRAGMA user_version = 4');
      await store.close();
      store = AppDatabase(NativeDatabase(file));
      final expense = (await store.tripDao.getExpensesForTrip(tripId)).single;
      expect(expense.id, expenseId);
      expect(expense.amount, 5);
      expect(expense.destinationId, '');
      final city = PlanItem.create(
        'destination',
      ).copy({'title': 'Kyoto', 'date': '2026-10-01', 'endDate': '2026-10-01'});
      await TripPlanRepository(store, null).save(tripId, city);
      await TravelRepository(
        store,
        null,
        RateRepository(store, null),
      ).updateTravelExpense(
        expenseId,
        amount: 5,
        currency: 'SGD',
        date: start,
        category: 'Other',
        name: 'Water',
        destinationId: city.id,
      );
      await store.close();
      store = AppDatabase(NativeDatabase(file));
      expect(
        (await store.tripDao.getExpensesForTrip(tripId)).single.destinationId,
        city.id,
      );
      await store.close();
      await dir.delete(recursive: true);
    },
  );

  test('schema 3 migration keeps expense identity and payment survives restart',
      () async {
    final dir = await Directory.systemTemp.createTemp('numi-payment-migration');
    final file = File('${dir.path}/test.sqlite');
    var store = AppDatabase(NativeDatabase(file));
    final tripId = await store.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Existing',
        startDate: start,
        endDate: DateTime(2026, 10, 3)));
    final expenseId = await store.tripDao.insertTravelExpense(
        TravelExpensesCompanion.insert(
            tripId: tripId,
            remoteId: const Value(78),
            amount: 20,
            currency: 'SGD',
            date: start,
            category: 'Other',
            name: 'Ticket'));
    await store
        .customStatement('ALTER TABLE travel_expenses DROP COLUMN client_id');
    await store.customStatement(
      'ALTER TABLE travel_expenses DROP COLUMN plan_item_id',
    );
    await store.customStatement(
      'ALTER TABLE travel_expenses DROP COLUMN destination_id',
    );
    await store.customStatement('PRAGMA user_version = 3');
    await store.close();
    store = AppDatabase(NativeDatabase(file));
    final row = (await store.tripDao.getExpensesForTrip(tripId)).single;
    expect(row.id, expenseId);
    expect(row.clientId, 'remote-78');
    var planner = TripPlanRepository(store, null);
    await planner.save(
        tripId, await planner.itemFromExpense(tripId, expenseId));
    await store.close();
    store = AppDatabase(NativeDatabase(file));
    planner = TripPlanRepository(store, null);
    expect(
        (await store.tripDao.getExpensesForTrip(tripId)).single.id, expenseId);
    expect((await planner.watch(tripId).first).pending, true);
    await store.close();
    await dir.delete(recursive: true);
  });

  test('schema 2 upgrade preserves trips and planning persists across restarts',
      () async {
    await db.close();
    dbClosed = true;
    final dir = await Directory.systemTemp.createTemp('numi-plan-migration');
    final file = File('${dir.path}/test.sqlite');
    var persistent = AppDatabase(NativeDatabase(file));
    final tripId = await persistent.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Existing', startDate: start, endDate: start));
    await persistent.customStatement('DROP TABLE trip_plans');
    await persistent
        .customStatement('ALTER TABLE travel_expenses DROP COLUMN client_id');
    await persistent.customStatement(
      'ALTER TABLE travel_expenses DROP COLUMN plan_item_id',
    );
    await persistent.customStatement(
      'ALTER TABLE travel_expenses DROP COLUMN destination_id',
    );
    await persistent.customStatement('PRAGMA user_version = 2');
    await persistent.close();
    persistent = AppDatabase(NativeDatabase(file));
    expect((await persistent.tripDao.getById(tripId))!.destination, 'Existing');
    await TripPlanRepository(persistent, null).save(tripId, place('Persisted'));
    await persistent.close();
    persistent = AppDatabase(NativeDatabase(file));
    final plan = await TripPlanRepository(persistent, null).watch(tripId).first;
    expect(plan.items.single.title, 'Persisted');
    expect(plan.pending, true);
    await persistent.close();
    await dir.delete(recursive: true);
  });
  test(
      'participants default to everyone and specific people survive serialization',
      () async {
    final me = PlanItem.create('person').copy({'title': 'Me'});
    final nyt = PlanItem.create('person').copy({'title': 'NYT'});
    final together = PlanItem.create('activity')
        .copy({'title': 'Lunch', 'date': '2026-10-01'});
    final solo = PlanItem.create('activity').copy(
        {'title': 'NYT flight', 'date': '2026-10-01'},
        participantIds: [nyt.id]);
    var plan =
        TripPlan.decode(TripPlan(items: [me, nyt, together, solo]).encode());
    expect(plan.timelineOn('2026-10-01', person: me.id).map((i) => i.title),
        ['Lunch']);
    expect(plan.timelineOn('2026-10-01', person: nyt.id).map((i) => i.title),
        ['Lunch', 'NYT flight']);
    expect(plan.participantsLabel(plan.find(solo.id)!), 'NYT');
    final third = PlanItem.create('person').copy({'title': 'Third'});
    plan = TripPlan(items: [...plan.items, third]);
    expect(plan.matchesPerson(together, third.id), true);
    expect(plan.matchesPerson(solo, third.id), false);
    final repo = TripPlanRepository(db, null);
    for (final item in plan.items) {
      await repo.save(id, item);
    }
    expect(
        (await repo.watch(id).first).find(solo.id)!.participantIds, [nyt.id]);
  });

  test(
      'in-flight local edits retain remote additions and unrelated changed fields',
      () {
    final a =
        PlanItem.create('activity').copy({'title': 'A', 'notes': 'Before'});
    final remoteOnly = PlanItem.create('activity').copy({'title': 'B'});
    final base = TripPlan(items: [a]);
    final local = TripPlan(items: [
      a.copy({'time': '09:00'})
    ]);
    final remote = TripPlan(items: [
      a.copy({'notes': 'From friend'}),
      remoteOnly
    ]);
    final result = mergePlanChanges(base, local, remote);
    expect(result.find(a.id)!['time'], '09:00');
    expect(result.find(a.id)!['notes'], 'From friend');
    expect(result.find(remoteOnly.id), isNotNull);
    expect(
        () => mergePlanChanges(
            base,
            TripPlan(items: [
              a.copy({'notes': 'Local'})
            ]),
            remote),
        throwsStateError);
  });
  test('missing booking times are unconfirmed while activities remain flexible',
      () {
    final hotel = PlanItem.create('booking').copy(
        {'title': 'Hotel', 'date': '2026-10-07', 'endDate': '2026-10-09'});
    final plan = TripPlan(items: [hotel]);
    expect(plan.timelineTimeLabel(hotel, '2026-10-09'), 'Time TBD');
    expect(
        plan.timelineTimeLabel(hotel.copy({'endTime': '12:00'}), '2026-10-09'),
        '12:00');
    expect(plan.timelineTimeLabel(PlanItem.create('activity'), '2026-10-09'),
        'Anytime');
  });
}
