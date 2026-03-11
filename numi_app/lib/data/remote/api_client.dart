import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import '../../utils/app_logger.dart';

class ApiClient {
  final String baseUrl;
  late final Dio _dio;
  final CookieJar _cookieJar = CookieJar();
  bool _csrfFetched = false;

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
    // Log response type for debugging parse failures
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final ct = response.headers.value('content-type') ?? 'unknown';
        if (!ct.contains('json')) {
          final body = response.data?.toString() ?? '';
          final snippet = body.substring(0, body.length.clamp(0, 200));
          AppLogger.instance.log(
            '${response.requestOptions.path} returned non-JSON: '
            'content-type=$ct body=$snippet',
            name: 'API',
          );
        }
        handler.next(response);
      },
    ));
    // CSRF interceptor MUST be added before CookieManager so it can
    // populate the cookie jar (via a GET) before CookieManager sets the
    // Cookie header on the outgoing request.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.method != 'GET') {
          try {
            final uri = Uri.parse(baseUrl);
            var cookies = await _cookieJar.loadForRequest(uri);
            Cookie? csrf = _findCsrf(cookies);

            // Auto-fetch CSRF token if we don't have one yet.
            if (csrf == null && !_csrfFetched) {
              _csrfFetched = true;
              await _dio.get('/api/rates/');
              cookies = await _cookieJar.loadForRequest(uri);
              csrf = _findCsrf(cookies);
            }

            if (csrf != null) {
              options.headers['X-CSRFToken'] = csrf.value;
            }
          } catch (_) {}
        }
        handler.next(options);
      },
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static Cookie? _findCsrf(List<Cookie> cookies) {
    for (final c in cookies) {
      if (c.name == 'csrftoken') return c;
    }
    return null;
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
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } catch (e) {
      final log = AppLogger.instance;
      if (e is DioException) {
        final body = e.response?.data?.toString() ?? 'null';
        final snippet = body.substring(0, body.length.clamp(0, 300));
        log.log('GET $path failed: status=${e.response?.statusCode} '
            'type=${e.type} body=$snippet', name: 'API');
      } else {
        log.log('GET $path error: $e', name: 'API');
      }
      rethrow;
    }
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
