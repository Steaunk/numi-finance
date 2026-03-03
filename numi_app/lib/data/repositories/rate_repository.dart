import '../../config/constants.dart';
import '../local/database.dart';
import '../remote/endpoints/rate_api.dart';

class RateRepository {
  final AppDatabase _db;
  final RateApi? _api;

  RateRepository(this._db, this._api);

  Future<void> fetchAndCacheRates() async {
    final api = _api;
    if (api == null) return;
    try {
      final rates = await api.getRates();
      final fb = AppConstants.fallbackRates;
      await _db.exchangeRateDao.insertRow(
        ExchangeRatesCompanion.insert(
          rateDate: DateTime.now(),
          cny: rates['cny'] ?? fb['cny']!,
          hkd: rates['hkd'] ?? fb['hkd']!,
          sgd: rates['sgd'] ?? fb['sgd']!,
          jpy: rates['jpy'] ?? fb['jpy']!,
        ),
      );
    } catch (_) {}
  }

  Future<Map<String, double>> getCachedRates() async {
    final rate = await _db.exchangeRateDao.getLatest();
    if (rate != null) {
      return {'cny': rate.cny, 'hkd': rate.hkd, 'sgd': rate.sgd, 'jpy': rate.jpy};
    }
    return Map<String, double>.from(AppConstants.fallbackRates);
  }
}
