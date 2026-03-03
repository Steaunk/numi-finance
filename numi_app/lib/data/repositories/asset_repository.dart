import 'dart:convert';
import 'package:drift/drift.dart';
import '../../models/account.dart' as model;
import '../../models/balance_snapshot.dart' as model;
import '../../utils/currency_utils.dart';
import '../../utils/date_utils.dart';
import '../local/database.dart';
import '../remote/endpoints/asset_api.dart';
import 'rate_repository.dart';

class AssetRepository {
  final AppDatabase _db;
  final AssetApi? _api;
  final RateRepository _rateRepo;

  AssetRepository(this._db, this._api, this._rateRepo);

  Stream<List<model.Account>> watchAllAccounts(String displayCurrency) {
    return _db.accountDao.watchAll().asyncMap((rows) async {
      final rates = await _rateRepo.getCachedRates();
      return rows.map((row) {
        final converted =
            CurrencyUtils.convert(row.balance, row.currency, displayCurrency, rates);
        return _rowToModel(row, convertedBalance: converted);
      }).toList();
    });
  }

  Future<double> getNetWorth(String displayCurrency) async {
    final accounts = await _db.accountDao.getAll();
    final rates = await _rateRepo.getCachedRates();
    double total = 0;
    for (final acc in accounts) {
      if (!acc.includeInTotal) continue;
      total += CurrencyUtils.convert(acc.balance, acc.currency, displayCurrency, rates);
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> getNetWorthTrend(
      String displayCurrency) async {
    // Try fetching from API (has full historical data)
    final api = _api;
    if (api != null) {
      try {
        final data = await api.getTrend(currency: displayCurrency);
        final dates = List<String>.from(data['dates'] as List);
        final values = List<num>.from(data['values'] as List);
        final result = <Map<String, dynamic>>[];
        for (var i = 0; i < dates.length; i++) {
          result.add({'date': dates[i], 'total': values[i].toDouble()});
        }
        return result;
      } catch (_) {}
    }

    // Fall back to local snapshots
    final snapshots = await _db.accountDao.getAllSnapshots();
    if (snapshots.isEmpty) return [];

    final byDate = <String, double>{};
    final accountMap = <int, DbAccount>{};
    final allAccounts = await _db.accountDao.getAll();
    for (final a in allAccounts) {
      accountMap[a.id] = a;
    }

    for (final snap in snapshots) {
      final account = accountMap[snap.accountId];
      if (account == null || !account.includeInTotal) continue;
      final dateKey = AppDateUtils.formatDate(snap.snapshotDate);
      final amount = CurrencyUtils.getDisplayAmount(
        displayCurrency: displayCurrency,
        amountUsd: snap.amountUsd,
        amountCny: snap.amountCny,
        amountHkd: snap.amountHkd,
        amountSgd: snap.amountSgd,
      );
      byDate.update(dateKey, (v) => v + amount, ifAbsent: () => amount);
    }

    final sorted = byDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => {'date': e.key, 'total': e.value}).toList();
  }

  Stream<List<model.BalanceSnapshot>> watchAccountHistory(int accountId) {
    return _db.accountDao.watchSnapshotsForAccount(accountId).map(
          (rows) => rows.map(_snapshotToModel).toList(),
        );
  }

  Future<void> addAccount({
    required String name,
    required String currency,
    required double balance,
    bool includeInTotal = true,
    String notes = '',
  }) async {
    final companion = AccountsCompanion.insert(
      name: name,
      currency: currency,
      balance: Value(balance),
      includeInTotal: Value(includeInTotal),
      notes: Value(notes),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
    final localId = await _db.accountDao.insertRow(companion);

    final api = _api;
    if (api != null) {
      try {
        final remote = await api.addAccount({
          'name': name,
          'currency': currency,
          'balance': balance,
          'include_in_total': includeInTotal,
          'notes': notes,
        });
        await (_db.update(_db.accounts)
              ..where((a) => a.id.equals(localId)))
            .write(AccountsCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
      } catch (_) {
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'account',
            operation: 'create',
            localId: localId,
            payload: jsonEncode({
              'name': name,
              'currency': currency,
              'balance': balance,
              'include_in_total': includeInTotal,
              'notes': notes,
            }),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> updateAccount(
    int localId, {
    required String name,
    required String currency,
    double? balance,
    required bool includeInTotal,
    required String notes,
  }) async {
    final existing = await _db.accountDao.getById(localId);
    if (existing == null) return;

    final newBalance = balance ?? existing.balance;
    final now = DateTime.now();

    // Record snapshot locally if balance changed
    if (balance != null && balance != existing.balance) {
      final rates = await _rateRepo.getCachedRates();
      final computed = CurrencyUtils.computeAmounts(newBalance, currency, rates);
      await _db.accountDao.insertSnapshot(
        BalanceSnapshotsCompanion.insert(
          accountId: localId,
          balance: newBalance,
          change: Value(newBalance - existing.balance),
          snapshotDate: now,
          amountUsd: Value(computed['amount_usd']!),
          amountCny: Value(computed['amount_cny']!),
          amountHkd: Value(computed['amount_hkd']!),
          amountSgd: Value(computed['amount_sgd']!),
        ),
      );
    }

    await _db.accountDao.replaceRow(existing.copyWith(
      name: name,
      currency: currency,
      balance: newBalance,
      includeInTotal: includeInTotal,
      notes: notes,
      updatedAt: Value(now),
      synced: false,
    ));

    await _pushAccount(localId);
  }

  /// Push a single account to the server. Returns true on success.
  Future<bool> _pushAccount(int localId) async {
    final api = _api;
    final row = await _db.accountDao.getById(localId);
    if (api == null || row == null || row.remoteId == null) return false;
    try {
      await api.updateAccount(row.remoteId!, {
        'name': row.name,
        'currency': row.currency,
        'balance': row.balance,
        'include_in_total': row.includeInTotal,
        'notes': row.notes,
      });
      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(localId)))
          .write(const AccountsCompanion(synced: Value(true)));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Push all locally-modified accounts to the server before pulling.
  Future<void> pushUnsyncedAccounts() async {
    final all = await _db.accountDao.getAll();
    for (final acc in all) {
      if (!acc.synced && acc.remoteId != null) {
        await _pushAccount(acc.id);
      }
    }
  }

  Future<void> deleteAccount(int localId) async {
    final row = await _db.accountDao.getById(localId);
    await _db.accountDao.removeById(localId);

    final api = _api;
    if (api != null && row?.remoteId != null) {
      try {
        await api.deleteAccount(row!.remoteId!);
      } catch (_) {}
    }
  }

  Future<void> syncFromServer(String currency) async {
    final api = _api;
    if (api == null) return;

    // Push local changes first so the server has the latest data
    await pushUnsyncedAccounts();

    try {
      final accounts = await api.getAccounts(currency: currency);
      for (final a in accounts) {
        final remoteId = a['id'] as int;
        // Skip overwriting accounts with pending local changes
        final existing = await ((_db.select(_db.accounts))
              ..where((row) => row.remoteId.equals(remoteId)))
            .getSingleOrNull();
        if (existing != null && !existing.synced) continue;

        await _db.accountDao.upsertByRemoteId(
          AccountsCompanion(
            remoteId: Value(remoteId),
            name: Value(a['name'] as String),
            currency: Value(a['currency'] as String),
            balance: Value((a['balance'] as num).toDouble()),
            includeInTotal: Value(a['include_in_total'] as bool? ?? true),
            notes: Value(a['notes'] as String? ?? ''),
            synced: const Value(true),
          ),
        );
      }
    } catch (_) {}
  }

  model.Account _rowToModel(DbAccount row, {double convertedBalance = 0}) =>
      model.Account(
        id: row.id,
        remoteId: row.remoteId,
        name: row.name,
        currency: row.currency,
        balance: row.balance,
        includeInTotal: row.includeInTotal,
        notes: row.notes,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        synced: row.synced,
        convertedBalance: convertedBalance,
      );

  model.BalanceSnapshot _snapshotToModel(DbBalanceSnapshot row) =>
      model.BalanceSnapshot(
        id: row.id,
        accountId: row.accountId,
        balance: row.balance,
        change: row.change,
        snapshotDate: row.snapshotDate,
        amountUsd: row.amountUsd,
        amountCny: row.amountCny,
        amountHkd: row.amountHkd,
        amountSgd: row.amountSgd,
      );
}
