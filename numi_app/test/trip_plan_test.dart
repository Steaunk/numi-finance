import 'dart:convert';
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

class ExpenseApiFake extends PlanApiFake {
  final ledger = <int, Map<String, dynamic>>{};
  Future<void> Function()? beforeCreate;
  Future<void> Function()? beforeUpdate;
  @override
  Future<Map<String, dynamic>> addTripExpense(
      int tripId, Map<String, dynamic> data) async {
    if (offline) throw StateError('offline');
    final existing = ledger.entries
        .where((e) => e.value['client_id'] == data['client_id'])
        .firstOrNull;
    final id = existing?.key ?? ledger.length + 1;
    ledger.putIfAbsent(id, () => {...data, 'id': id});
    await beforeCreate?.call();
    return {'id': id};
  }

  @override
  Future<Map<String, dynamic>> updateTripExpense(
      int tripId, int id, Map<String, dynamic> data) async {
    if (offline) throw StateError('offline');
    await beforeUpdate?.call();
    ledger[id] = {...data, 'id': id};
    return ledger[id]!;
  }

  @override
  Future<void> deleteTripExpense(int tripId, int id) async {
    ledger.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getTripExpenses(int tripId,
          {String currency = 'SGD'}) async =>
      ledger.values.toList();
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

  PlanItem booking() => PlanItem.create('booking')
      .copy({'title': 'Hotel', 'date': '2026-10-01', 'endDate': '2026-10-03'});

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
    final visit =
        booking().copy({'kind': 'activity', 'title': '', 'placeId': sight.id});
    await repo.save(id, visit);
    final rail = booking().copy({
      'title': 'Train',
      'category': 'Train',
      'destinationId': tokyo.id,
      'endDestinationId': kyoto.id
    });
    await repo.save(id, rail);
    var plan = await read(repo);
    expect(plan.destinationsOn('2026-10-02').length, 2);
    expect(plan.destinationIdFor(visit), kyoto.id);
    expect(plan.expenseDestination([visit.id]), kyoto.id);
    expect(plan.expenseDestination([rail.id]), '__transfers__');
    expect(plan.matchesDestination(rail, tokyo.id), true);
    expect(plan.matchesDestination(rail, kyoto.id), true);
    expect(plan.expenseDestination([]), '');
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
    expect(await db.tripDao.getExpensesForTrip(id), isEmpty);
    await expectLater(
        repo.save(id, place('Dangling').copy({'destinationId': kyoto.id})),
        throwsStateError);
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
      expect(expense.planItemIds, isEmpty);
      expect(plan.items.length, 1);
      expect(
        plan.expenseDestination(
          expense.planItemIds,
          destinationId: expense.destinationId,
        ),
        city.id,
      );
      await localPlanner.remove(id, city.id);
      final kept = (await travel.getTripWithExpenses(id))!.expenses.single;
      expect(kept.id, expense.id);
      expect(kept.amount, 5);
      expect(kept.destinationId, '');
      expect(kept.planItemIds, isEmpty);
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
      await store.customStatement(
          'ALTER TABLE travel_expenses DROP COLUMN plan_item_ids');
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
    await store.customStatement(
        'ALTER TABLE travel_expenses DROP COLUMN plan_item_ids');
    await store.customStatement('PRAGMA user_version = 3');
    await store.close();
    store = AppDatabase(NativeDatabase(file));
    final row = (await store.tripDao.getExpensesForTrip(tripId)).single;
    expect(row.id, expenseId);
    expect(row.clientId, 'remote-78');
    var planner = TripPlanRepository(store, null);
    await planner.save(tripId, booking());
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
    await persistent.customStatement(
        'ALTER TABLE travel_expenses DROP COLUMN plan_item_ids');
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
  test('expenses link many arrangements without creating or pricing plans',
      () async {
    final planner = TripPlanRepository(db, null);
    final first = PlanItem.create('activity')
        .copy({'title': 'Museum', 'category': 'Sightseeing'});
    final second = booking();
    await planner.save(id, first);
    await planner.save(id, second);
    final travel = TravelRepository(db, null, RateRepository(db, null));
    for (final name in ['Tickets', 'Pass']) {
      await travel.addTravelExpense(
          tripId: id,
          amount: 20,
          currency: 'SGD',
          date: start,
          category: 'Sightseeing',
          name: name,
          planItemIds: [first.id, second.id]);
    }
    final rows = (await travel.getTripWithExpenses(id))!.expenses;
    expect(rows.length, 2);
    expect(rows.every((e) => e.planItemIds.length == 2), true);
    expect(rows.fold<double>(0, (sum, e) => sum + e.amount), 40);
    await planner.save(
        id, first.copy({'category': 'Shopping', 'title': 'Museum shop'}));
    expect((await travel.getTripWithExpenses(id))!.expenses.first.amount, 20);
    await planner.remove(id, first.id);
    expect(
        (await travel.getTripWithExpenses(id))!
            .expenses
            .every((e) => e.planItemIds.single == second.id),
        true);
    await travel.updateTravelExpense(rows.first.id,
        amount: 25,
        currency: 'SGD',
        date: start,
        category: 'Sightseeing',
        name: 'Tickets',
        planItemIds: []);
    expect((await read(planner)).items.length, 1);
    await travel.deleteTravelExpense(rows.last.id, id);
    expect((await read(planner)).find(second.id), isNotNull);
    expect((await travel.getTripWithExpenses(id))!.expenses.single.planItemIds,
        isEmpty);
    await expectLater(
        travel.addTravelExpense(
            tripId: id,
            amount: 20,
            currency: 'SGD',
            date: start,
            category: 'Other',
            name: 'Invalid',
            planItemIds: ['foreign']),
        throwsStateError);
  });

  test(
      'schema 5 migration keeps links, amounts and strips plan prices after restart',
      () async {
    final dir = await Directory.systemTemp.createTemp('numi-link-migration');
    final file = File('${dir.path}/db');
    var store = AppDatabase(NativeDatabase(file));
    final trip = await store.tripDao.insertTrip(TripsCompanion.insert(
        destination: 'Tokyo', startDate: start, endDate: start));
    await store.tripDao.insertTravelExpense(TravelExpensesCompanion.insert(
        tripId: trip,
        planItemId: const Value('museum'),
        amount: 2200,
        currency: 'JPY',
        date: start,
        category: 'Sightseeing',
        name: 'Ticket'));
    await store.into(store.tripPlans).insert(TripPlansCompanion(
        tripId: Value(trip),
        content: Value(jsonEncode({
          'items': [
            {
              'id': 'museum',
              'kind': 'activity',
              'title': 'Museum',
              'category': 'Activity',
              'expenseCategory': 'Sightseeing',
              'amount': '2200',
              'currency': 'JPY',
              'paymentStatus': 'paid'
            }
          ]
        }))));
    await store.customStatement(
        'ALTER TABLE travel_expenses DROP COLUMN plan_item_ids');
    await store.customStatement('PRAGMA user_version = 5');
    await store.close();
    store = AppDatabase(NativeDatabase(file));
    final row = (await store.tripDao.getExpensesForTrip(trip)).single;
    expect(jsonDecode(row.planItemIds), ['museum']);
    expect(row.amount, 2200);
    expect(row.planItemId, isNull);
    final plan = await TripPlanRepository(store, null).watch(trip).first;
    expect(plan.find('museum')!['amount'], '');
    expect(plan.find('museum')!['category'], 'Sightseeing');
    await store.close();
    await dir.delete(recursive: true);
  });
  test('expense edits during upload keep newest links and amount after retry',
      () async {
    final remote = ExpenseApiFake();
    final planner = TripPlanRepository(db, remote);
    final a = PlanItem.create('activity').copy({'title': 'Museum'}),
        b = PlanItem.create('activity').copy({'title': 'Park'});
    await planner.save(id, a);
    await planner.save(id, b);
    await planner.sync(id);
    final entered = Completer<void>(), release = Completer<void>();
    remote.beforeUpdate = () async {
      if (!entered.isCompleted) {
        entered.complete();
        await release.future;
      }
    };
    final travel = TravelRepository(db, remote, RateRepository(db, null));
    await travel.addTravelExpense(
        tripId: id,
        amount: 20,
        currency: 'SGD',
        date: start,
        category: 'Other',
        name: 'Pass',
        planItemIds: [a.id]);
    await entered.future;
    final first = (await db.tripDao.getExpensesForTrip(id)).single;
    await travel.updateTravelExpense(first.id,
        amount: 40,
        currency: 'SGD',
        date: start,
        category: 'Other',
        name: 'Pass',
        planItemIds: [a.id, b.id]);
    release.complete();
    await travel.flushExpenses();
    final row = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(row.amount, 40);
    expect(row.synced, true);
    expect(remote.ledger.length, 1);
    expect(remote.ledger.values.single['plan_item_ids'], [a.id, b.id]);
    expect(remote.ledger.values.single['amount'], 40);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('deleting an expense during creation cleans up the remote record',
      () async {
    final remote = ExpenseApiFake();
    final entered = Completer<void>(), release = Completer<void>();
    remote.beforeCreate = () async {
      entered.complete();
      await release.future;
    };
    final travel = TravelRepository(db, remote, RateRepository(db, null));
    await travel.addTravelExpense(
        tripId: id,
        amount: 20,
        currency: 'SGD',
        date: start,
        category: 'Other',
        name: 'Pass');
    await entered.future;
    final row = (await db.tripDao.getExpensesForTrip(id)).single;
    await travel.deleteTravelExpense(row.id, id);
    release.complete();
    await travel.flushExpenses();
    expect(remote.ledger, isEmpty);
    expect(await db.tripDao.getExpensesForTrip(id), isEmpty);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('museum aliases suggest review only for the same visit', () {
    final a = PlanItem.create('activity').copy({
      'title': 'YAYOI KUSAMA MUSEUM',
      'date': '2026-10-10',
      'time': '11:00'
    });
    final b = a.copy({'title': '草間彌生美術館 - YAYOI KUSAMA MUSEUM'});
    expect(sameScheduledActivity(a, b), true);
    expect(sameScheduledActivity(a, b.copy({'time': '12:00'})), false);
    expect(sameScheduledActivity(a, b.copy({'date': '2026-10-11'})), false);
    expect(sameScheduledActivity(a, b.copy({'title': 'Other Museum'})), false);
  });
}
