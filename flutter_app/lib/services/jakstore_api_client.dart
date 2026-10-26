import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class ApiTokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureApiTokenStorage implements ApiTokenStorage {
  const _SecureApiTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class JakStoreApiClient {
  JakStoreApiClient({
    required String baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    ApiTokenStorage? tokenStorage,
  })  : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = httpClient ?? http.Client(),
        _storage = tokenStorage ??
            _SecureApiTokenStorage(
              secureStorage ?? const FlutterSecureStorage(),
            );

  static const tokenKey = 'jakstore_api_token';
  final Uri _baseUri;
  final http.Client _http;
  final ApiTokenStorage _storage;
  String? _token;
  void Function()? onUnauthorized;

  bool get hasToken => _token != null;

  Future<Map<String, dynamic>?> restoreSession() async {
    _token = await _storage.read(tokenKey);
    if (_token == null) return null;
    try {
      return await get('/me');
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await clearSession();
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _send(
      'POST',
      '/login',
      body: {
        'email': email,
        'password': password,
        'device_name': 'JakStore Android',
      },
    );
    final token = data['token'];
    final user = data['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const ApiException('Respons login dari server tidak valid.');
    }
    _token = token;
    await _storage.write(tokenKey, token);
    return user;
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        await post('/logout');
      } finally {
        await clearSession();
      }
    } else {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _token = null;
    await _storage.delete(tokenKey);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, Object?> body,
  }) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final uri = _baseUri.resolve(path.replaceFirst(RegExp(r'^/'), '')).replace(
          queryParameters: query,
        );
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      late final http.Response response;
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers).timeout(
                const Duration(seconds: 20),
              );
        case 'POST':
          response = await _http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
        case 'PATCH':
          response = await _http
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
        default:
          throw StateError('Unsupported HTTP method: $method');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Server mengirim respons yang tidak valid.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && _token != null) {
          await clearSession();
          onUnauthorized?.call();
        }
        final errors = decoded['errors'];
        final firstError = errors is Map
            ? errors.values
                .whereType<List>()
                .expand((items) => items)
                .whereType<String>()
                .firstOrNull
            : null;
        throw ApiException(
          firstError ??
              (decoded['message'] is String
                  ? decoded['message'] as String
                  : 'Permintaan gagal (${response.statusCode}).'),
          statusCode: response.statusCode,
        );
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'items': data, 'meta': decoded['meta']};
      throw const ApiException('Format data respons server tidak dikenali.');
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw const ApiException(
        'Tidak dapat terhubung ke server. Periksa alamat API dan jaringan.',
      );
    } on FormatException {
      throw const ApiException('Server mengirim JSON yang tidak valid.');
    } on Exception catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw const ApiException('Server tidak merespons dalam batas waktu.');
      }
      rethrow;
    }
  }
}
