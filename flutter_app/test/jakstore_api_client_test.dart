import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jakstore_admin/services/jakstore_api_client.dart';

class _MemoryTokenStorage implements ApiTokenStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  group('JakStoreApiClient', () {
    test('uses the configured API path and unwraps paginated collections',
        () async {
      final storage = _MemoryTokenStorage();
      final client = JakStoreApiClient(
        baseUrl: 'https://example.test/api',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/inventory');
          expect(request.url.queryParameters, {'page': '1'});
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 1, 'imei1': '490154203237518'},
              ],
              'meta': {'last_page': 1},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final response = await client.get(
        '/inventory',
        query: {'page': '1'},
      );

      expect(response['items'], [
        {'id': 1, 'imei1': '490154203237518'},
      ]);
      expect(response['meta'], {'last_page': 1});
    });

    test('stores login token securely and sends it on authenticated calls',
        () async {
      final storage = _MemoryTokenStorage();
      final client = JakStoreApiClient(
        baseUrl: 'https://example.test/api/',
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/login') {
            return http.Response(
              jsonEncode({
                'data': {
                  'token': 'test-access-token',
                  'user': {'id': 1, 'name': 'Admin'},
                },
              }),
              200,
            );
          }
          expect(
            request.headers['authorization'],
            'Bearer test-access-token',
          );
          return http.Response(
              jsonEncode({
                'data': {'id': 1}
              }),
              200);
        }),
      );

      await client.login(email: 'admin@example.test', password: 'password');
      expect(storage.values[JakStoreApiClient.tokenKey], 'test-access-token');
      expect(await client.get('/me'), {'id': 1});
    });

    test('surfaces the first server validation error', () async {
      final client = JakStoreApiClient(
        baseUrl: 'https://example.test/api',
        tokenStorage: _MemoryTokenStorage(),
        httpClient: MockClient((_) async => http.Response(
              jsonEncode({
                'message': 'The given data was invalid.',
                'errors': {
                  'imei1': ['IMEI sudah terdaftar.'],
                },
              }),
              422,
            )),
      );

      await expectLater(
        client.post('/inventory'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 422)
              .having(
                  (error) => error.message, 'message', 'IMEI sudah terdaftar.'),
        ),
      );
    });
  });
}
