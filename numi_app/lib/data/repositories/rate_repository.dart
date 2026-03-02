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
      await _db.exchangeRateDao.insertRow(
        ExchangeRatesCompanion.insert(
          rateDate: DateTime.now(),
          cny: rates['cny'] ?? 7.25,
          hkd: rates['hkd'] ?? 7.82,
          sgd: rates['sgd'] ?? 1.34,
          jpy: rates['jpy'] ?? 150.0,
        ),
      );
    } catch (_) {}
  }

  Future<Map<String, double>> getCachedRates() async {
    final rate = await _db.exchangeRateDao.getLatest();
    if (rate != null) {
      return {'cny': rate.cny, 'hkd': rate.hkd, 'sgd': rate.sgd, 'jpy': rate.jpy};
    }
    return {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0};
  }
}
