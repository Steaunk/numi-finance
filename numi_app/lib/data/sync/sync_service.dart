import 'dart:convert';
import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import '../local/database.dart';
import '../remote/endpoints/expense_api.dart';
import '../remote/endpoints/travel_api.dart';
import '../remote/endpoints/asset_api.dart';
import '../repositories/expense_repository.dart';
import '../repositories/travel_repository.dart';
import '../repositories/asset_repository.dart';
import '../repositories/rate_repository.dart';

class SyncService {
  static const _maxRetries = 5;
  final AppDatabase _db;
  final ExpenseApi _expenseApi;
  final TravelApi _travelApi;
  final AssetApi _assetApi;
  final ExpenseRepository _expenseRepo;
  final TravelRepository _travelRepo;
  final AssetRepository _assetRepo;
  final RateRepository _rateRepo;

  SyncService({
    required AppDatabase db,
    required ExpenseApi expenseApi,
    required TravelApi travelApi,
    required AssetApi assetApi,
    required ExpenseRepository expenseRepo,
    required TravelRepository travelRepo,
    required AssetRepository assetRepo,
    required RateRepository rateRepo,
  })  : _db = db,
        _expenseApi = expenseApi,
        _travelApi = travelApi,
        _assetApi = assetApi,
        _expenseRepo = expenseRepo,
        _travelRepo = travelRepo,
        _assetRepo = assetRepo,
        _rateRepo = rateRepo;

  /// Strip ISO8601 time portion for date-only API fields.
  static String _toDateStr(dynamic v) =>
      v is String && v.contains('T') ? v.split('T').first : v.toString();

  Future<void> fullSync(String currency) async {
    await _rateRepo.fetchAndCacheRates();
    await Future.wait([
      _expenseRepo.syncFromServer(currency),
      _travelRepo.syncFromServer(currency),
      _assetRepo.syncFromServer(currency),
    ]);
    await _processSyncQueue();
  }

  Future<void> _processSyncQueue() async {
    final pending = await _db.syncQueueDao.getPending();
    for (final op in pending) {
      if (op.retryCount >= _maxRetries) {
        developer.log(
          'Sync op ${op.id} (${op.entityType}/${op.operation}) exceeded '
          '$_maxRetries retries, removing',
          name: 'SyncService',
        );
        await _db.syncQueueDao.removeById(op.id);
        continue;
      }
      try {
        bool handled = false;
        switch (op.entityType) {
          case 'expense':
            handled = await _handleExpenseOp(op);
          case 'trip':
            handled = await _handleTripOp(op);
          case 'travel_expense':
            handled = await _handleTravelExpenseOp(op);
          case 'account':
            handled = await _handleAccountOp(op);
        }
        if (handled) {
          await _db.syncQueueDao.removeById(op.id);
        }
      } catch (e, st) {
        developer.log(
          'Sync op ${op.id} (${op.entityType}/${op.operation}) failed: $e',
          name: 'SyncService',
          error: e,
          stackTrace: st,
        );
        await _db.syncQueueDao.incrementRetry(op.id);
      }
    }
  }

  Future<bool> _handleExpenseOp(DbSyncOperation op) async {
    final p = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.operation) {
      case 'create':
        final remote = await _expenseApi.addExpense({
          'amount': p['amount'],
          'currency': p['currency'],
          'date': _toDateStr(p['date']),
          'category': p['category'],
          'name': p['name'],
          'notes': p['notes'] ?? '',
        });
        await _db.expenseDao.markSynced(op.localId, remote['id'] as int);
        return true;
      case 'update':
        final row = await (_db.select(_db.expenses)
              ..where((e) => e.id.equals(op.localId)))
            .getSingleOrNull();
        if (row?.remoteId == null) return false;
        await _expenseApi.updateExpense(row!.remoteId!, {
          'amount': p['amount'],
          'currency': p['currency'],
          'date': _toDateStr(p['date']),
          'category': p['category'],
          'name': p['name'],
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.expenses)
              ..where((e) => e.id.equals(op.localId)))
            .write(const ExpensesCompanion(synced: Value(true)));
        return true;
      case 'delete':
        final remoteId = p['remote_id'] as int?;
        if (remoteId != null) await _expenseApi.deleteExpense(remoteId);
        return true;
      default:
        return false;
    }
  }

  Future<bool> _handleTripOp(DbSyncOperation op) async {
    final p = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.operation) {
      case 'create':
        final remote = await _travelApi.addTrip({
          'destination': p['destination'],
          'start_date': _toDateStr(p['start_date']),
          'end_date': _toDateStr(p['end_date']),
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.trips)
              ..where((t) => t.id.equals(op.localId)))
            .write(TripsCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
        return true;
      case 'delete':
        final remoteId = p['remote_id'] as int?;
        if (remoteId != null) await _travelApi.deleteTrip(remoteId);
        return true;
      default:
        return false;
    }
  }

  Future<bool> _handleTravelExpenseOp(DbSyncOperation op) async {
    final p = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.operation) {
      case 'create':
        final tripRow = await _db.tripDao.getById(p['trip_id'] as int);
        if (tripRow?.remoteId == null) return false;
        final remote = await _travelApi.addTripExpense(tripRow!.remoteId!, {
          'amount': p['amount'],
          'currency': p['currency'],
          'date': _toDateStr(p['date']),
          'category': p['category'],
          'name': p['name'],
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.travelExpenses)
              ..where((e) => e.id.equals(op.localId)))
            .write(TravelExpensesCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
        return true;
      case 'update':
        final localRow = await (_db.select(_db.travelExpenses)
              ..where((e) => e.id.equals(op.localId)))
            .getSingleOrNull();
        if (localRow?.remoteId == null || localRow?.tripRemoteId == null) {
          return false;
        }
        await _travelApi.updateTripExpense(
            localRow!.tripRemoteId!, localRow.remoteId!, {
          'amount': p['amount'],
          'currency': p['currency'],
          'date': _toDateStr(p['date']),
          'category': p['category'],
          'name': p['name'],
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.travelExpenses)
              ..where((e) => e.id.equals(op.localId)))
            .write(const TravelExpensesCompanion(synced: Value(true)));
        return true;
      case 'delete':
        final remoteId = p['remote_id'] as int?;
        final tripRemoteId = p['trip_remote_id'] as int?;
        if (remoteId != null && tripRemoteId != null) {
          await _travelApi.deleteTripExpense(tripRemoteId, remoteId);
        }
        return true;
      default:
        return false;
    }
  }

  Future<bool> _handleAccountOp(DbSyncOperation op) async {
    final p = jsonDecode(op.payload) as Map<String, dynamic>;
    switch (op.operation) {
      case 'create':
        final remote = await _assetApi.addAccount({
          'name': p['name'],
          'currency': p['currency'],
          'balance': p['balance'],
          'include_in_total': p['include_in_total'],
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.accounts)
              ..where((a) => a.id.equals(op.localId)))
            .write(AccountsCompanion(
          remoteId: Value(remote['id'] as int),
          synced: const Value(true),
        ));
        return true;
      case 'update':
        final row = await _db.accountDao.getById(op.localId);
        if (row?.remoteId == null) return false;
        await _assetApi.updateAccount(row!.remoteId!, {
          'name': p['name'],
          'currency': p['currency'],
          'balance': p['balance'],
          'include_in_total': p['include_in_total'],
          'notes': p['notes'] ?? '',
        });
        await (_db.update(_db.accounts)
              ..where((a) => a.id.equals(op.localId)))
            .write(const AccountsCompanion(synced: Value(true)));
        return true;
      case 'delete':
        final remoteId = p['remote_id'] as int?;
        if (remoteId != null) await _assetApi.deleteAccount(remoteId);
        return true;
      default:
        return false;
    }
  }
}
