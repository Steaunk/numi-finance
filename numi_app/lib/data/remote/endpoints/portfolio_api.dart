import '../api_client.dart';

class PortfolioApi {
  final ApiClient _client;
  PortfolioApi(this._client);

  Future<Map<String, dynamic>> getHoldings() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/portfolio/api/holdings/',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAccount() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/portfolio/api/account/',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHistory({int days = 30}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/portfolio/api/history/',
      queryParameters: {'days': days},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStockHistory(
    String stockName, {
    int days = 30,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/portfolio/api/stock/$stockName/history/',
      queryParameters: {'days': days},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBrokerValues() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/portfolio/api/broker-values/',
    );
    return response.data as Map<String, dynamic>;
  }
}
