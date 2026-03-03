import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ── Tables ───────────────────────────────────────────────────────────────────

@DataClassName('DbExpense')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get amountUsd => real().withDefault(const Constant(0))();
  RealColumn get amountCny => real().withDefault(const Constant(0))();
  RealColumn get amountHkd => real().withDefault(const Constant(0))();
  RealColumn get amountSgd => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbTrip')
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get destination => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbTravelExpense')
class TravelExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  IntColumn get tripId => integer().references(Trips, #id)();
  IntColumn get tripRemoteId => integer().nullable()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get amountUsd => real().withDefault(const Constant(0))();
  RealColumn get amountCny => real().withDefault(const Constant(0))();
  RealColumn get amountHkd => real().withDefault(const Constant(0))();
  RealColumn get amountSgd => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbAccount')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get remoteId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get currency => text()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  BoolColumn get includeInTotal => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DataClassName('DbBalanceSnapshot')
class BalanceSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  RealColumn get balance => real()();
  RealColumn get change => real().withDefault(const Constant(0))();
  DateTimeColumn get snapshotDate => dateTime()();
  RealColumn get amountUsd => real().withDefault(const Constant(0))();
  RealColumn get amountCny => real().withDefault(const Constant(0))();
  RealColumn get amountHkd => real().withDefault(const Constant(0))();
  RealColumn get amountSgd => real().withDefault(const Constant(0))();
}

@DataClassName('DbExchangeRate')
class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get rateDate => dateTime()();
  RealColumn get cny => real()();
  RealColumn get hkd => real()();
  RealColumn get sgd => real()();
  RealColumn get jpy => real()();
}

@DataClassName('DbSyncOperation')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get operation => text()();
  IntColumn get localId => integer()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

// ── DAOs ─────────────────────────────────────────────────────────────────────

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Stream<int> watchPendingCount() {
    return select(syncQueue).watch().map((rows) => rows.length);
  }

  Future<void> enqueue(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<List<DbSyncOperation>> getPending() => select(syncQueue).get();

  Future<void> removeById(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();
}

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  Stream<List<DbExpense>> watchByMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return (select(expenses)
          ..where(
            (e) =>
                e.date.isBiggerOrEqualValue(start) &
                e.date.isSmallerThanValue(end),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Future<List<String>> getDistinctCategories() async {
    final query = selectOnly(expenses, distinct: true)
      ..addColumns([expenses.category])
      ..orderBy([OrderingTerm.asc(expenses.category)]);
    final rows = await query.get();
    return rows.map((r) => r.read(expenses.category)!).toList();
  }

  Future<List<DbExpense>> getAll({int? year}) {
    if (year == null) return select(expenses).get();
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    return (select(expenses)
          ..where(
            (e) =>
                e.date.isBiggerOrEqualValue(start) &
                e.date.isSmallerThanValue(end),
          ))
        .get();
  }

  Future<int> insertRow(ExpensesCompanion entry) =>
      into(expenses).insert(entry);

  Future<void> removeById(int id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();

  Future<void> upsertByRemoteId(ExpensesCompanion entry) async {
    final remoteId = entry.remoteId.value;
    if (remoteId == null) return;
    final existing = await (select(expenses)
          ..where((e) => e.remoteId.equals(remoteId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(expenses)..where((e) => e.remoteId.equals(remoteId)))
          .write(entry);
    } else {
      await into(expenses).insert(entry, mode: InsertMode.insertOrIgnore);
    }
  }

  Future<void> updateRow(int id, ExpensesCompanion companion) =>
      (update(expenses)..where((e) => e.id.equals(id))).write(companion);

  Future<void> markSynced(int localId, int remoteId) async {
    await (update(expenses)..where((e) => e.id.equals(localId))).write(
      ExpensesCompanion(remoteId: Value(remoteId), synced: const Value(true)),
    );
  }
}

@DriftAccessor(tables: [Trips, TravelExpenses])
class TripDao extends DatabaseAccessor<AppDatabase> with _$TripDaoMixin {
  TripDao(super.db);

  Stream<List<DbTrip>> watchAll() =>
      (select(trips)
            ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
          .watch();

  Future<DbTrip?> getById(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DbTravelExpense>> getExpensesForTrip(int tripId) =>
      (select(travelExpenses)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Stream<List<DbTravelExpense>> watchExpensesForTrip(int tripId) =>
      (select(travelExpenses)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  Future<int> insertTrip(TripsCompanion entry) => into(trips).insert(entry);

  Future<void> removeTripById(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  Future<int> insertTravelExpense(TravelExpensesCompanion entry) =>
      into(travelExpenses).insert(entry);

  Future<void> removeTravelExpenseById(int id) =>
      (delete(travelExpenses)..where((e) => e.id.equals(id))).go();

  Future<void> updateTravelExpenseRow(
          int id, TravelExpensesCompanion companion) =>
      (update(travelExpenses)..where((e) => e.id.equals(id))).write(companion);

  Future<void> upsertTripByRemoteId(TripsCompanion entry) async {
    final remoteId = entry.remoteId.value;
    if (remoteId == null) return;
    final existing = await (select(trips)
          ..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(trips)..where((t) => t.remoteId.equals(remoteId)))
          .write(entry);
    } else {
      await into(trips).insert(entry, mode: InsertMode.insertOrIgnore);
    }
  }

  Future<void> upsertTravelExpenseByRemoteId(
      TravelExpensesCompanion entry) async {
    final remoteId = entry.remoteId.value;
    if (remoteId == null) return;
    final existing = await (select(travelExpenses)
          ..where((e) => e.remoteId.equals(remoteId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(travelExpenses)
            ..where((e) => e.remoteId.equals(remoteId)))
          .write(entry);
    } else {
      await into(travelExpenses)
          .insert(entry, mode: InsertMode.insertOrIgnore);
    }
  }
}

@DriftAccessor(tables: [Accounts, BalanceSnapshots])
class AccountDao extends DatabaseAccessor<AppDatabase>
    with _$AccountDaoMixin {
  AccountDao(super.db);

  Stream<List<DbAccount>> watchAll() =>
      (select(accounts)..orderBy([(a) => OrderingTerm.asc(a.name)])).watch();

  Future<DbAccount?> getById(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<List<DbAccount>> getAll() => select(accounts).get();

  Future<int> insertRow(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<void> replaceRow(DbAccount account) =>
      (update(accounts)..where((a) => a.id.equals(account.id)))
          .replace(account);

  Future<void> removeById(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  Future<int> insertSnapshot(BalanceSnapshotsCompanion entry) =>
      into(balanceSnapshots).insert(entry);

  Stream<List<DbBalanceSnapshot>> watchSnapshotsForAccount(int accountId) =>
      (select(balanceSnapshots)
            ..where((s) => s.accountId.equals(accountId))
            ..orderBy([(s) => OrderingTerm.desc(s.snapshotDate)]))
          .watch();

  Future<List<DbBalanceSnapshot>> getAllSnapshots() =>
      select(balanceSnapshots).get();

  Future<void> upsertByRemoteId(AccountsCompanion entry) async {
    final remoteId = entry.remoteId.value;
    if (remoteId == null) return;
    final existing = await (select(accounts)
          ..where((a) => a.remoteId.equals(remoteId)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(accounts)..where((a) => a.remoteId.equals(remoteId)))
          .write(entry);
    } else {
      await into(accounts).insert(entry, mode: InsertMode.insertOrIgnore);
    }
  }
}

@DriftAccessor(tables: [ExchangeRates])
class ExchangeRateDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeRateDaoMixin {
  ExchangeRateDao(super.db);

  Future<DbExchangeRate?> getLatest() =>
      (select(exchangeRates)
            ..orderBy([(r) => OrderingTerm.desc(r.rateDate)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> insertRow(ExchangeRatesCompanion entry) async {
    // Keep only the latest rates entry
    await delete(exchangeRates).go();
    await into(exchangeRates).insert(entry);
  }
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Expenses,
    Trips,
    TravelExpenses,
    Accounts,
    BalanceSnapshots,
    ExchangeRates,
    SyncQueue,
  ],
  daos: [
    SyncQueueDao,
    ExpenseDao,
    TripDao,
    AccountDao,
    ExchangeRateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final oldFile = File(p.join(dbFolder.path, 'expense_tracker.db'));
    final newFile = File(p.join(dbFolder.path, 'numi.db'));
    if (oldFile.existsSync() && !newFile.existsSync()) {
      oldFile.renameSync(newFile.path);
    }
    return NativeDatabase.createInBackground(newFile);
  });
}
