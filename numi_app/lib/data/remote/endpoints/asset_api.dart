import '../api_client.dart';

class AssetApi {
  final ApiClient _client;
  AssetApi(this._client);

  Future<List<Map<String, dynamic>>> getAccounts({
    String currency = 'SGD',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/assets/api/accounts/',
      queryParameters: {'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['accounts'] as List);
  }

  Future<Map<String, dynamic>> addAccount(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/assets/api/accounts/add/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAccount(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/assets/api/accounts/$id/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount(int id) =>
      _client.delete('/assets/api/accounts/$id/delete/');

  Future<double> getNetWorth({String currency = 'SGD'}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/assets/api/net-worth/',
      queryParameters: {'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num).toDouble();
  }

  Future<Map<String, dynamic>> getTrend({String currency = 'SGD'}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/assets/api/trend/',
      queryParameters: {'currency': currency},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAccountHistory(int accountId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/assets/api/accounts/$accountId/history/',
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['snapshots'] as List? ?? []);
  }

  Future<List<Map<String, dynamic>>> syncApiAccounts({int? id}) async {
    final path = id != null
        ? '/assets/api/accounts/sync/?id=$id'
        : '/assets/api/accounts/sync/';
    final response = await _client.post<Map<String, dynamic>>(path);
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['results'] as List);
  }
}
