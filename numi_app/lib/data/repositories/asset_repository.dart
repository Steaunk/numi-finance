import 'dart:convert';
import '../../utils/app_logger.dart';
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
      } catch (e, st) {
        AppLogger.instance.log('getNetWorthTrend API failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
      }
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
    String? apiUrl,
    String? apiValuePath,
    String? apiAuth,
  }) async {
    final companion = AccountsCompanion.insert(
      name: name,
      currency: currency,
      balance: Value(balance),
      includeInTotal: Value(includeInTotal),
      notes: Value(notes),
      apiUrl: Value(apiUrl),
      apiValuePath: Value(apiValuePath),
      apiAuth: Value(apiAuth),
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
          if (apiUrl != null) 'api_url': apiUrl,
          if (apiValuePath != null) 'api_value_path': apiValuePath,
          if (apiAuth != null) 'api_auth': apiAuth,
        });
        await (_db.update(_db.accounts)
              ..where((a) => a.id.equals(localId)))
            .write(AccountsCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
      } catch (e, st) {
        AppLogger.instance.log('addAccount push failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
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
              if (apiUrl != null) 'api_url': apiUrl,
              if (apiValuePath != null) 'api_value_path': apiValuePath,
              if (apiAuth != null) 'api_auth': apiAuth,
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
    String? apiUrl,
    String? apiValuePath,
    String? apiAuth,
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
      apiUrl: Value(apiUrl),
      apiValuePath: Value(apiValuePath),
      apiAuth: Value(apiAuth),
      updatedAt: Value(now),
      synced: false,
    ));

    final pushed = await _pushAccount(localId);
    if (!pushed) {
      await _db.syncQueueDao.enqueue(
        SyncQueueCompanion.insert(
          entityType: 'account',
          operation: 'update',
          localId: localId,
          payload: jsonEncode({
            'name': name,
            'currency': currency,
            'balance': newBalance,
            'include_in_total': includeInTotal,
            'notes': notes,
            if (apiUrl != null) 'api_url': apiUrl,
            if (apiValuePath != null) 'api_value_path': apiValuePath,
            if (apiAuth != null) 'api_auth': apiAuth,
          }),
          createdAt: Value(DateTime.now()),
        ),
      );
    }
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
        'api_url': row.apiUrl ?? '',
        'api_value_path': row.apiValuePath ?? '',
        'api_auth': row.apiAuth ?? '',
      });
      await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(localId)))
          .write(const AccountsCompanion(synced: Value(true)));
      return true;
    } catch (e, st) {
      AppLogger.instance.log('updateAccount push failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> deleteAccount(int localId) async {
    final row = await _db.accountDao.getById(localId);
    await _db.accountDao.removeById(localId);

    final api = _api;
    if (api != null && row?.remoteId != null) {
      try {
        await api.deleteAccount(row!.remoteId!);
      } catch (e, st) {
        AppLogger.instance.log('deleteAccount push failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
        await _db.syncQueueDao.enqueue(
          SyncQueueCompanion.insert(
            entityType: 'account',
            operation: 'delete',
            localId: localId,
            payload: jsonEncode({'remote_id': row!.remoteId}),
            createdAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> syncFromServer(String currency) async {
    final api = _api;
    if (api == null) return;
    try {
      final rates = await _rateRepo.getCachedRates();
      final accounts = await api.getAccounts(currency: currency);
      for (final a in accounts) {
        final remoteId = a['id'] as int;
        // Skip overwriting accounts with pending local changes
        final existing = await ((_db.select(_db.accounts))
              ..where((row) => row.remoteId.equals(remoteId)))
            .getSingleOrNull();
        if (existing != null && !existing.synced) continue;

        final newBalance = (a['balance'] as num).toDouble();
        final newCurrency = a['currency'] as String;
        final apiUrl = a['api_url'] as String?;
        final apiValuePath = a['api_value_path'] as String?;
        final apiAuth = a['api_auth'] as String?;
        await _db.accountDao.upsertByRemoteId(
          AccountsCompanion(
            remoteId: Value(remoteId),
            name: Value(a['name'] as String),
            currency: Value(newCurrency),
            balance: Value(newBalance),
            includeInTotal: Value(a['include_in_total'] as bool? ?? true),
            notes: Value(a['notes'] as String? ?? ''),
            apiUrl: Value(apiUrl != null && apiUrl.isNotEmpty ? apiUrl : null),
            apiValuePath: Value(apiValuePath != null && apiValuePath.isNotEmpty ? apiValuePath : null),
            apiAuth: Value(apiAuth != null && apiAuth.isNotEmpty ? apiAuth : null),
            synced: const Value(true),
          ),
        );

        // Record snapshot if balance changed (so charts update)
        if (existing != null && existing.balance != newBalance) {
          final localId = existing.id;
          final computed = CurrencyUtils.computeAmounts(newBalance, newCurrency, rates);
          await _db.accountDao.insertSnapshot(
            BalanceSnapshotsCompanion.insert(
              accountId: localId,
              balance: newBalance,
              change: Value(newBalance - existing.balance),
              snapshotDate: DateTime.now(),
              amountUsd: Value(computed['amount_usd']!),
              amountCny: Value(computed['amount_cny']!),
              amountHkd: Value(computed['amount_hkd']!),
              amountSgd: Value(computed['amount_sgd']!),
            ),
          );
        } else if (existing == null) {
          // New account from server — record initial snapshot
          final inserted = await ((_db.select(_db.accounts))
                ..where((row) => row.remoteId.equals(remoteId)))
              .getSingleOrNull();
          if (inserted != null && newBalance != 0) {
            final computed = CurrencyUtils.computeAmounts(newBalance, newCurrency, rates);
            await _db.accountDao.insertSnapshot(
              BalanceSnapshotsCompanion.insert(
                accountId: inserted.id,
                balance: newBalance,
                change: Value(newBalance),
                snapshotDate: DateTime.now(),
                amountUsd: Value(computed['amount_usd']!),
                amountCny: Value(computed['amount_cny']!),
                amountHkd: Value(computed['amount_hkd']!),
                amountSgd: Value(computed['amount_sgd']!),
              ),
            );
          }
        }
      }
    } catch (e, st) {
      AppLogger.instance.log('syncFromServer failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
    }
  }

  /// Transfer funds between two local accounts.
  /// Handles currency conversion if accounts use different currencies.
  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
  }) async {
    final from = await _db.accountDao.getById(fromAccountId);
    final to = await _db.accountDao.getById(toAccountId);
    if (from == null || to == null) return;

    final rates = await _rateRepo.getCachedRates();
    final now = DateTime.now();

    // Convert amount to destination currency if different
    final convertedAmount = from.currency == to.currency
        ? amount
        : CurrencyUtils.convert(amount, from.currency, to.currency, rates);

    final newFromBalance = from.balance - amount;
    final newToBalance = to.balance + convertedAmount;

    // Update source account
    await _db.accountDao.replaceRow(from.copyWith(
      balance: newFromBalance,
      updatedAt: Value(now),
      synced: false,
    ));
    final fromComputed = CurrencyUtils.computeAmounts(newFromBalance, from.currency, rates);
    await _db.accountDao.insertSnapshot(
      BalanceSnapshotsCompanion.insert(
        accountId: fromAccountId,
        balance: newFromBalance,
        change: Value(-amount),
        snapshotDate: now,
        amountUsd: Value(fromComputed['amount_usd']!),
        amountCny: Value(fromComputed['amount_cny']!),
        amountHkd: Value(fromComputed['amount_hkd']!),
        amountSgd: Value(fromComputed['amount_sgd']!),
      ),
    );

    // Update destination account
    await _db.accountDao.replaceRow(to.copyWith(
      balance: newToBalance,
      updatedAt: Value(now),
      synced: false,
    ));
    final toComputed = CurrencyUtils.computeAmounts(newToBalance, to.currency, rates);
    await _db.accountDao.insertSnapshot(
      BalanceSnapshotsCompanion.insert(
        accountId: toAccountId,
        balance: newToBalance,
        change: Value(convertedAmount),
        snapshotDate: now,
        amountUsd: Value(toComputed['amount_usd']!),
        amountCny: Value(toComputed['amount_cny']!),
        amountHkd: Value(toComputed['amount_hkd']!),
        amountSgd: Value(toComputed['amount_sgd']!),
      ),
    );

    // Push both accounts to server
    await _pushAccount(fromAccountId);
    await _pushAccount(toAccountId);
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
        apiUrl: row.apiUrl,
        apiValuePath: row.apiValuePath,
        apiAuth: row.apiAuth,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        synced: row.synced,
        convertedBalance: convertedBalance,
      );

  Future<void> syncApiAccounts() async {
    final api = _api;
    if (api == null) return;
    try {
      await api.syncApiAccounts();
    } catch (e, st) {
      AppLogger.instance.log('syncApiAccounts failed: $e', name: 'AssetRepo', error: e, stackTrace: st);
    }
  }

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
