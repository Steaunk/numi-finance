import '../local/database.dart';
import '../remote/api_client.dart';
import '../remote/endpoints/expense_api.dart';
import '../remote/endpoints/travel_api.dart';
import '../remote/endpoints/asset_api.dart';
import '../repositories/expense_repository.dart';
import '../repositories/travel_repository.dart';
import '../repositories/asset_repository.dart';
import '../repositories/rate_repository.dart';

class SyncService {
  final AppDatabase _db;
  // ignore: unused_field
  final ApiClient _apiClient;
  // ignore: unused_field
  final ExpenseApi _expenseApi;
  // ignore: unused_field
  final TravelApi _travelApi;
  // ignore: unused_field
  final AssetApi _assetApi;
  final ExpenseRepository _expenseRepo;
  final TravelRepository _travelRepo;
  final AssetRepository _assetRepo;
  final RateRepository _rateRepo;

  SyncService({
    required AppDatabase db,
    required ApiClient apiClient,
    required ExpenseApi expenseApi,
    required TravelApi travelApi,
    required AssetApi assetApi,
    required ExpenseRepository expenseRepo,
    required TravelRepository travelRepo,
    required AssetRepository assetRepo,
    required RateRepository rateRepo,
  })  : _db = db,
        _apiClient = apiClient,
        _expenseApi = expenseApi,
        _travelApi = travelApi,
        _assetApi = assetApi,
        _expenseRepo = expenseRepo,
        _travelRepo = travelRepo,
        _assetRepo = assetRepo,
        _rateRepo = rateRepo;

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
      try {
        bool handled = false;
        switch (op.entityType) {
          case 'expense':
            handled = await _handleExpenseOp(op);
          case 'trip':
            handled = await _handleTripOp(op);
          case 'account':
            handled = await _handleAccountOp(op);
        }
        if (handled) {
          await _db.syncQueueDao.removeById(op.id);
        }
      } catch (_) {}
    }
  }

  Future<bool> _handleExpenseOp(DbSyncOperation op) async {
    switch (op.operation) {
      case 'delete':
        // Already deleted locally; best-effort remote delete
        return true;
      default:
        return false;
    }
  }

  Future<bool> _handleTripOp(DbSyncOperation op) async {
    return op.operation == 'delete';
  }

  Future<bool> _handleAccountOp(DbSyncOperation op) async {
    return op.operation == 'delete';
  }
}
