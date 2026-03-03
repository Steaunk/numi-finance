import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ApiClient {
  final String baseUrl;
  late final Dio _dio;
  final CookieJar _cookieJar = CookieJar();

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
    _dio.interceptors.add(CookieManager(_cookieJar));
    // Forward Django's csrftoken cookie as X-CSRFToken header on write requests.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.method != 'GET') {
          try {
            final uri = Uri.parse(baseUrl);
            final cookies = await _cookieJar.loadForRequest(uri);
            Cookie? csrf;
            for (final c in cookies) {
              if (c.name == 'csrftoken') {
                csrf = c;
                break;
              }
            }
            if (csrf != null) {
              options.headers['X-CSRFToken'] = csrf.value;
            }
          } catch (_) {}
        }
        handler.next(options);
      },
    ));
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
