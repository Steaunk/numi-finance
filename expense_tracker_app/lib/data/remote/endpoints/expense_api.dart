import '../api_client.dart';

class ExpenseApi {
  final ApiClient _client;
  ExpenseApi(this._client);

  Future<List<Map<String, dynamic>>> getExpenses({
    required String month,
    String currency = 'SGD',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/api/expenses/',
      queryParameters: {'month': month, 'currency': currency},
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['expenses'] as List);
  }

  Future<Map<String, dynamic>> addExpense(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/expenses/api/expenses/add/',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteExpense(int id) =>
      _client.delete('/expenses/api/expenses/$id/');

  Future<List<String>> getCategories() async {
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/api/categories/',
    );
    final data = response.data as Map<String, dynamic>;
    return List<String>.from(data['categories'] as List);
  }

  Future<Map<String, dynamic>> getMonthlyStats({
    String currency = 'SGD',
    int? year,
  }) async {
    final params = <String, dynamic>{'currency': currency};
    if (year != null) params['year'] = year.toString();
    final response = await _client.get<Map<String, dynamic>>(
      '/expenses/api/stats/monthly/',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }
}
