import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ApiClient {
  final String baseUrl;
  late final Dio _dio;

  ApiClient(this.baseUrl, {String? username, String? password}) {
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (username != null && username.isNotEmpty && password != null) {
      final creds = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $creds';
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: headers,
      ),
    );
    _dio.interceptors.add(CookieManager(CookieJar()));
  }

  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/api/rates/');
      return response.statusCode != null && response.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
