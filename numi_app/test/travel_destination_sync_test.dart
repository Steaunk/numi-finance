import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/remote/endpoints/travel_api.dart';
import 'package:numi_app/data/remote/endpoints/asset_api.dart';
import 'package:numi_app/data/remote/endpoints/expense_api.dart';
import 'package:numi_app/data/repositories/travel_repository.dart';
import 'package:numi_app/data/repositories/trip_plan_repository.dart';
import 'package:numi_app/data/repositories/asset_repository.dart';
import 'package:numi_app/data/repositories/expense_repository.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';
import 'package:numi_app/data/sync/sync_service.dart';
import 'package:numi_app/models/trip_plan.dart';

class _TravelApi implements TravelApi {
  Map<String, dynamic> content = {'items': []};
  final expenses = <String, Map<String, dynamic>>{};
  final uploads = <String>[];
  int revision = 0;
  bool offline = false;
  void connected() {
    if (offline) throw StateError('offline');
  }

  @override
  Future<List<Map<String, dynamic>>> getTrips({String currency = 'SGD'}) async {
    connected();
    return [
      {
        'id': 10,
        'destination': 'Japan',
        'start_date': '2026-10-01',
        'end_date': '2026-10-03'
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> getPlan(int id) async {
    connected();
    return {
      'content': content,
      'revision': revision,
      'payment_ids': <String, int>{}
    };
  }

  @override
  Future<Map<String, dynamic>> putPlan(
      int id, Map<String, dynamic> payload) async {
    connected();
    content = Map<String, dynamic>.from(payload['content'] as Map);
    revision++;
    uploads.add('plan');
    return getPlan(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getTripExpenses(int id,
      {String currency = 'SGD'}) async {
    connected();
    return expenses.values.toList();
  }

  @override
  Future<Map<String, dynamic>> addTripExpense(
      int id, Map<String, dynamic> payload) async {
    connected();
    final destination = payload['destination_id'];
    expect((content['items'] as List).any((i) => i['id'] == destination), true,
        reason: 'The destination must upload before its expense');
    uploads.add('expense');
    return expenses.putIfAbsent(
        payload['client_id'] as String, () => {...payload, 'id': 55});
  }

  @override
  Future<Map<String, dynamic>> updateTripExpense(
      int tripId, int expenseId, Map<String, dynamic> payload) async {
    connected();
    final key = expenses.keys.single;
    return expenses[key] = {...expenses[key]!, ...payload};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OtherApis implements AssetApi, ExpenseApi {
  @override
  Future<Map<String, dynamic>> getAccountIcons({String? version}) async =>
      {'changed': false};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'offline city expenses retry after the plan, update and pull without losing their city',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final id = await db.tripDao.insertTrip(TripsCompanion.insert(
        remoteId: const Value(10),
        synced: const Value(true),
        destination: 'Japan',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3)));
    final city = PlanItem.create('destination').copy(
        {'title': 'Kyoto', 'date': '2026-10-01', 'endDate': '2026-10-03'});
    await TripPlanRepository(db, null).save(id, city);
    final rates = RateRepository(db, null);
    final offlineTravel = TravelRepository(db, null, rates);
    await offlineTravel.addTravelExpense(
        tripId: id,
        amount: 5,
        currency: 'SGD',
        date: DateTime(2026, 10, 1),
        category: 'Other',
        name: 'Water',
        destinationId: city.id);
    final api = _TravelApi()..offline = true;
    final travel = TravelRepository(db, api, rates);
    final other = _OtherApis();
    final service = SyncService(
        db: db,
        travelApi: api,
        expenseApi: other,
        assetApi: other,
        travelRepo: travel,
        planRepo: TripPlanRepository(db, api),
        expenseRepo: ExpenseRepository(db, null, rates),
        assetRepo: AssetRepository(db, null, rates),
        rateRepo: rates,
        prefs: await SharedPreferences.getInstance());
    await service.fullSync('SGD');
    expect(await db.syncQueueDao.getPending(), isNotEmpty);
    api.offline = false;
    await service.fullSync('SGD');
    expect(api.uploads, ['plan', 'expense']);
    expect(api.expenses.values.single['destination_id'], city.id);
    expect(await db.syncQueueDao.getPending(), isEmpty);
    final expense = (await db.tripDao.getExpensesForTrip(id)).single;
    api.offline = true;
    await travel.updateTravelExpense(expense.id,
        amount: 7,
        currency: 'SGD',
        date: expense.date,
        category: 'Other',
        name: 'Water',
        destinationId: city.id);
    api.offline = false;
    await service.fullSync('SGD');
    expect(api.expenses.length, 1);
    expect(api.expenses.values.single['amount'], 7);
    expect(api.expenses.values.single['destination_id'], city.id);
    await db.tripDao.updateTravelExpenseRow(
        expense.id, const TravelExpensesCompanion(destinationId: Value('')));
    await travel.syncFromServer('SGD');
    final pulled = (await db.tripDao.getExpensesForTrip(id)).single;
    expect(pulled.destinationId, city.id);
    expect(pulled.planItemId, null);
  });
}
