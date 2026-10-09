import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/remote/api_client.dart';
import 'package:numi_app/data/remote/endpoints/travel_api.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/models/trip_plan.dart';

class FakeTravelApi extends TravelApi {
  bool offline = true;
  bool loseCreateResponse = false;
  bool losePlanResponse = false;
  int tripCreates = 0, expenseCreates = 0;
  int revision = 0;
  Map<String, dynamic> document = {};
  final receipts = <String, Map<String, dynamic>>{};
  final expenseAmounts = <num>[];
  final calls = <String>[];
  Completer<void>? planGate;
  Completer<void>? planStarted;
  FakeTravelApi() : super(ApiClient('https://example.invalid'));
  void check() {
    if (offline) throw StateError('offline');
  }

  @override
  Future<Map<String, dynamic>> addTrip(Map<String, dynamic> payload) async {
    check();
    calls.add('trip.create');
    final key = payload['_mutation_id'] as String;
    final result = receipts.putIfAbsent(key, () {
      tripCreates++;
      return {'id': 100};
    });
    if (loseCreateResponse) {
      loseCreateResponse = false;
      throw StateError('response lost');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> addTripExpense(
      int tripId, Map<String, dynamic> payload) async {
    check();
    calls.add('expense.create');
    expect(tripId, 100);
    return receipts.putIfAbsent(payload['_mutation_id'] as String, () {
      expenseCreates++;
      expenseAmounts.add(payload['amount']);
      return {'id': 200};
    });
  }

  @override
  Future<Map<String, dynamic>> updateTripExpense(
      int tripId, int expenseId, Map<String, dynamic> payload) async {
    check();
    calls.add('expense.update');
    expect(tripId, 100);
    expect(expenseId, 200);
    return receipts.putIfAbsent(payload['_mutation_id'] as String, () {
      expenseAmounts.add(payload['amount']);
      return {'id': expenseId};
    });
  }

  @override
  Future<void> deleteTrip(int id, {Map<String, dynamic>? payload}) async {
    check();
    calls.add('trip.delete');
  }

  @override
  Future<void> deleteTripExpense(int tripId, int expenseId,
      {Map<String, dynamic>? payload}) async {
    check();
    calls.add('expense.delete');
  }

  @override
  Future<Map<String, dynamic>> getPlan(int tripId) async {
    check();
    return {'version': revision, 'document': document};
  }

  @override
  Future<Map<String, dynamic>> putPlan(
      int tripId, Map<String, dynamic> payload) async {
    check();
    if (planStarted != null && !planStarted!.isCompleted) {
      planStarted!.complete();
    }
    await planGate?.future;
    final key = payload['_mutation_id'] as String;
    if (receipts.containsKey(key)) return receipts[key]!;
    if (payload['version'] != revision) {
      throw DioException(
          requestOptions: RequestOptions(path: '/plan'),
          response: Response(
              requestOptions: RequestOptions(path: '/plan'),
              statusCode: 409,
              data: {'version': revision, 'document': document}));
    }
    document = Map<String, dynamic>.from(payload['document']);
    revision++;
    final result = {'version': revision, 'document': document};
    receipts[key] = result;
    if (losePlanResponse) {
      losePlanResponse = false;
      throw StateError('response lost');
    }
    return result;
  }
}

void main() {
  late AppDatabase db;
  late FakeTravelApi api;
  late TravelRepository travel;
  late TripPlanRepository planner;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeTravelApi();
    travel = TravelRepository(db, api, RateRepository(db, null));
    planner = TripPlanRepository(db, api, travel);
  });
  tearDown(() async {
    await travel.syncPending();
    await planner.sync();
    await db.close();
  });
  Future<int> trip() async {
    await travel.addTrip(
        destination: 'Tokyo',
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 12));
    await travel.syncPending();
    return (await db.select(db.trips).getSingle()).id;
  }

  Future<void> addExpense(int id) => travel.addTravelExpense(
      tripId: id,
      amount: 20,
      currency: 'USD',
      date: DateTime(2026, 10, 10),
      category: 'Food & Drinks',
      name: 'Lunch',
      plannerEntryId: 'e' * 32);

  test(
      'offline parent and child persist atomically, survive >5 retries, then sync in order',
      () async {
    final id = await trip();
    await addExpense(id);
    await travel.syncPending();
    for (var i = 0; i < 7; i++) {
      await travel.syncPending();
    }
    expect(await db.syncQueueDao.getPending(), hasLength(2));
    api.offline = false;
    await travel.syncPending();
    expect(api.calls, ['trip.create', 'expense.create']);
    expect(await db.syncQueueDao.getPending(), isEmpty);
    final row = await db.select(db.travelExpenses).getSingle();
    expect(row.tripRemoteId, 100);
    expect(row.plannerEntryId, 'e' * 32);
    expect(row.synced, isTrue);
  });

  test('accepted create with a lost response reuses its persisted mutation id',
      () async {
    await trip();
    api.offline = false;
    api.loseCreateResponse = true;
    await travel.syncPending();
    expect(await db.syncQueueDao.getPending(), hasLength(1));
    await travel.syncPending();
    expect(api.tripCreates, 1);
    expect((await db.select(db.trips).getSingle()).remoteId, 100);
  });

  test(
      'multiple offline updates are not discarded when a prior operation succeeds',
      () async {
    final id = await trip();
    await addExpense(id);
    await travel.syncPending();
    final eid = (await db.select(db.travelExpenses).getSingle()).id;
    for (final amount in [30.0, 40.0]) {
      await travel.updateTravelExpense(eid,
          amount: amount,
          currency: 'USD',
          date: DateTime(2026, 10, 10),
          category: 'Food & Drinks',
          name: 'Lunch');
      await travel.syncPending();
    }
    api.offline = false;
    await travel.syncPending();
    expect(api.expenseAmounts, [20, 30, 40]);
    expect((await db.select(db.travelExpenses).getSingle()).amount, 40);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('offline deletion retains identity until remote deletion succeeds',
      () async {
    final id = await trip();
    await addExpense(id);
    await travel.syncPending();
    await travel.deleteTrip(id);
    await travel.syncPending();
    expect(await travel.getTripWithExpenses(id), isNull);
    expect(await db.select(db.trips).get(), hasLength(1));
    api.offline = false;
    await travel.syncPending();
    expect(api.calls.last, 'trip.delete');
    expect(await db.select(db.trips).get(), isEmpty);
    expect(await db.select(db.travelExpenses).get(), isEmpty);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('already-synced legacy create is removed without creating a duplicate',
      () async {
    final id = await trip();
    api.offline = false;
    await travel.syncPending();
    await db.syncQueueDao.enqueue(SyncQueueCompanion.insert(
        entityType: 'trip',
        operation: 'create',
        localId: id,
        payload: jsonEncode({'destination': 'Tokyo'})));
    await travel.syncPending();
    expect(api.tripCreates, 1);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('repairs legacy offline expense that never entered the queue', () async {
    final id = await trip();
    api.offline = false;
    await travel.syncPending();
    await db.into(db.travelExpenses).insert(TravelExpensesCompanion.insert(
        tripId: id,
        amount: 20,
        currency: 'USD',
        date: DateTime(2026, 10, 10),
        category: 'Food & Drinks',
        name: 'Legacy lunch'));
    await travel.syncPending();
    expect(api.expenseCreates, 1);
    expect((await db.select(db.travelExpenses).getSingle()).tripRemoteId, 100);
  });

  test(
      'offline plan survives reopening the repository and uploads after its trip',
      () async {
    final id = await trip();
    await planner.edit(
        id,
        (p) => p.saveEntry(
            PlanEntry(id: 'e' * 32, title: 'Museum', date: '2026-10-10')));
    await planner.sync();
    expect((await db.select(db.tripPlans).getSingle()).synced, isFalse);
    api.offline = false;
    final reopened = TripPlanRepository(db, api, travel);
    await reopened.sync();
    expect(api.tripCreates, 1);
    expect(api.document['entries'][0]['title'], 'Museum');
    expect((await db.select(db.tripPlans).getSingle()).synced, isTrue);
  });

  test('plan replay after response loss does not increment version twice',
      () async {
    final id = await trip();
    api.offline = false;
    api.losePlanResponse = true;
    await planner.edit(
        id, (p) => p.saveCheck(PlanCheck(id: 'c' * 32, title: 'Passport')));
    await planner.sync();
    expect(api.revision, 1);
    expect((await db.select(db.tripPlans).getSingle()).synced, isFalse);
    await planner.sync();
    expect(api.revision, 1);
    expect((await db.select(db.tripPlans).getSingle()).synced, isTrue);
  });

  test('conflicts retain both plans until user explicitly chooses server',
      () async {
    final id = await trip();
    api.document = {
      'entries': [PlanEntry(id: 's' * 32, title: 'Server museum').toJson()]
    };
    api.revision = 3;
    await planner.edit(
        id, (p) => p.saveEntry(PlanEntry(id: 'l' * 32, title: 'Local museum')));
    await planner.sync();
    api.offline = false;
    await planner.sync();
    var row = await db.select(db.tripPlans).getSingle();
    expect(TripPlan.decode(row.document).entries.single.title, 'Local museum');
    expect(TripPlan.decode(row.conflictDocument!).entries.single.title,
        'Server museum');
    await planner.resolve(id, keepMine: false);
    await planner.sync();
    row = await db.select(db.tripPlans).getSingle();
    expect(TripPlan.decode(row.document).entries.single.title, 'Server museum');
    expect(row.conflictDocument, isNull);
  });

  test('keep local retries against the server conflict version', () async {
    final id = await trip();
    api.revision = 5;
    await planner.edit(
        id, (p) => p.saveEntry(PlanEntry(id: 'l' * 32, title: 'Local museum')));
    await planner.sync();
    api.offline = false;
    await planner.sync();
    await planner.resolve(id, keepMine: true);
    await planner.sync();
    expect(api.revision, 6);
    expect(api.document['entries'][0]['title'], 'Local museum');
  });

  test('edits during an in-flight plan save are sent at the next revision',
      () async {
    final id = await trip();
    api.offline = false;
    await travel.syncPending();
    api.planGate = Completer();
    api.planStarted = Completer();
    await planner.edit(
        id, (p) => p.saveEntry(PlanEntry(id: 'e' * 32, title: 'Original')));
    await api.planStarted!.future;
    await planner.edit(
        id,
        (p) =>
            p.saveEntry(PlanEntry(id: 'e' * 32, title: 'Edited while saving')));
    api.planGate!.complete();
    await planner.sync();
    expect(api.revision, 2);
    expect(api.document['entries'][0]['title'], 'Edited while saving');
    expect(
        jsonDecode((await db.select(db.tripPlans).getSingle()).document)[
            'entries'][0]['title'],
        'Edited while saving');
  });
  test('oversized local edits fail atomically without losing the saved plan',
      () async {
    final id = await trip();
    await planner.edit(
        id, (p) => p.saveEntry(PlanEntry(id: 'e' * 32, title: 'Keep this')));
    await planner.sync();
    await expectLater(
        planner.edit(id, (p) {
          for (var i = 0; i < 1001; i++) {
            p.saveCheck(PlanCheck(
                id: 'check${i.toString().padLeft(20, '0')}', title: 'Item $i'));
          }
        }),
        throwsStateError);
    final saved =
        TripPlan.decode((await db.select(db.tripPlans).getSingle()).document);
    expect(saved.entries.single.title, 'Keep this');
    expect(saved.checks, isEmpty);
  });
}
