import '../api_client.dart';

class RateApi {
  final ApiClient _client;
  RateApi(this._client);

  /// Returns a map of lowercase currency code -> rate relative to USD.
  /// e.g. {'cny': 7.25, 'hkd': 7.82, 'sgd': 1.34, 'jpy': 150.0}
  Future<Map<String, double>> getRates({String? date}) async {
    final params = <String, dynamic>{
      'currencies': 'cny,hkd,sgd,jpy',
    };
    if (date != null) params['date'] = date;

    final response = await _client.get<Map<String, dynamic>>(
      '/api/rates/',
      queryParameters: params,
    );
    final data = response.data as Map<String, dynamic>;
    final rates = data['rates'] as Map<String, dynamic>;
    return rates.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}
