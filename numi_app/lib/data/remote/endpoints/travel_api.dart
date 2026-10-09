import '../api_client.dart';

class TravelApi {
  final ApiClient _client;
  TravelApi(this._client);

  Future<List<Map<String, dynamic>>> getTrips({String currency = 'SGD'}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/api/travel/trips/',
      queryParameters: {'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['trips'] as List);
  }

  Future<Map<String, dynamic>> addTrip(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/expenses/api/travel/trips/add/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewPdf(List<int> bytes, String name) =>
      _client.uploadPdf('/expenses/api/travel/pdf-preview/', bytes, name);

  Future<Map<String, dynamic>> attachPdf(
          int id, List<int> bytes, String name) =>
      _client.uploadPdf(
          '/expenses/api/travel/trips/$id/documents/', bytes, name);

  Future<
      List<
          int>> downloadPdf(int id, String documentId) => _client.downloadPdf(
      '/expenses/api/travel/trips/$id/documents/${Uri.encodeComponent(documentId)}/');

  Future<Map<String, dynamic>> previewShare(String text, String url) async {
    final response = await _client.post<Map<String, dynamic>>(
        '/expenses/api/travel/import-preview/',
        data: {'text': text, 'url': url});
    return response.data!;
  }

  Future<Map<String, dynamic>> getPlan(int id) async {
    final response = await _client
        .get<Map<String, dynamic>>('/expenses/api/travel/trips/$id/plan/');
    return response.data!;
  }

  Future<Map<String, dynamic>> putPlan(
      int id, Map<String, dynamic> payload) async {
    final response = await _client.put<Map<String, dynamic>>(
        '/expenses/api/travel/trips/$id/plan/',
        data: payload);
    return response.data!;
  }

  Future<void> deleteTripByClient(String clientId) => _client.delete(
      '/expenses/api/travel/trips/by-client/${Uri.encodeComponent(clientId)}/');

  Future<void> deleteTrip(int id) =>
      _client.delete('/expenses/api/travel/trips/$id/delete/');

  Future<List<Map<String, dynamic>>> getTripExpenses(
    int tripId, {
    String currency = 'SGD',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/api/travel/trips/$tripId/expenses/',
      queryParameters: {'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['expenses'] as List? ?? []);
  }

  Future<Map<String, dynamic>> addTripExpense(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/expenses/api/travel/trips/$tripId/expenses/add/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTripExpense(
    int tripId,
    int expenseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/expenses/api/travel/trips/$tripId/expenses/$expenseId/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteTripExpense(int tripId, int expenseId) => _client
      .delete('/expenses/api/travel/trips/$tripId/expenses/$expenseId/delete/');
}
