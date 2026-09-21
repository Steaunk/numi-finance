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
      if (p['revision'] != revision) throw error(409);
      revision++;
      content = Map<String, dynamic>.from(p['content'] as Map);
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
}
