import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/data/local/database.dart';
import 'package:numi_app/data/repositories/asset_repository.dart';
import 'package:numi_app/data/repositories/rate_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleting local history preserves current balance and other accounts',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AssetRepository(db, null, RateRepository(db, null));
    final bank = await db.accountDao.insertRow(AccountsCompanion.insert(
        name: 'ICBC', currency: 'SGD', balance: const Value(75873.26)));
    final other = await db.accountDao.insertRow(
        AccountsCompanion.insert(name: 'Other', currency: 'SGD'));
    final old = await db.accountDao.insertSnapshot(
        BalanceSnapshotsCompanion.insert(accountId: bank, balance: 59392.45,
            snapshotDate: DateTime(2026, 9, 1)));
    final latest = await db.accountDao.insertSnapshot(
        BalanceSnapshotsCompanion.insert(accountId: bank, balance: 75873.26,
            snapshotDate: DateTime(2026, 9, 2)));
    await repo.deleteLocalSnapshot(other, old);
    expect((await db.accountDao.getAllSnapshots()).length, 2);
    await repo.deleteLocalSnapshot(bank, old);
    expect((await db.accountDao.getAllSnapshots()).single.id, latest);
    expect((await db.accountDao.getById(bank))!.balance, 75873.26);
    expect(await db.syncQueueDao.getPending(), isEmpty);
  });

  test('offline trend uses latest daily balances and carries accounts forward',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = AssetRepository(db, null, RateRepository(db, null));
    final bank = await db.accountDao.insertRow(
        AccountsCompanion.insert(name: 'Bank', currency: 'SGD'));
    final broker = await db.accountDao.insertRow(
        AccountsCompanion.insert(name: 'Broker', currency: 'SGD'));
    final excluded = await db.accountDao.insertRow(AccountsCompanion.insert(
        name: 'Excluded', currency: 'SGD', includeInTotal: const Value(false)));
    Future<void> snapshot(int account, int day, int hour, double balance) async {
      await db.accountDao.insertSnapshot(BalanceSnapshotsCompanion.insert(
          accountId: account,
          balance: balance,
          snapshotDate: DateTime(2026, 9, day, hour),
          amountSgd: Value(balance)));
    }

    // Deliberately insert out of order and include multiple updates per day.
    await snapshot(bank, 5, 10, -10);
    await snapshot(bank, 1, 10, 100);
    await snapshot(broker, 1, 10, 50);
    await snapshot(bank, 1, 12, 120);
    await snapshot(excluded, 2, 10, 9000);
    await snapshot(broker, 3, 10, 70);
    await snapshot(bank, 5, 10, 0);
    expect(await repo.getNetWorthTrend('SGD'), [
      {'date': '2026-09-01', 'total': 170.0},
      {'date': '2026-09-03', 'total': 190.0},
      {'date': '2026-09-05', 'total': 70.0},
    ]);
  });
}
