import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jakstore_admin/services/api_device_identification_service.dart';
import 'package:jakstore_admin/services/device_identification_service.dart';
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
  test('sends an authenticated lookup and maps the Laravel device response',
      () async {
    final storage = _MemoryTokenStorage();
    final requests = <http.Request>[];
    final apiClient = JakStoreApiClient(
      baseUrl: 'https://jakstore.test/api',
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/login') {
          return _response({
            'data': {
              'token': 'test-session-token',
              'user': {'id': 1},
            },
          });
        }
        return _response({
          'data': {
            'status': 'identified',
            'message': 'Merek dan model ditemukan oleh provider lookup.',
            'device': {
              'brand': 'Samsung',
              'model_name': 'Galaxy S24',
              'model_code': 'SM-S921B',
              'source': 'IMEI.info',
            },
            'catalog_model': null,
            'catalog_variants': [],
          },
        });
      }),
    );
    await apiClient.login(
      email: 'admin@jakstore.test',
      password: 'test-password',
    );

    final result = await ApiDeviceIdentificationService(apiClient)
        .identify('490154203237518');

    expect(result.status, DeviceIdentificationStatus.identified);
    expect(result.device?.brand, 'Samsung');
    expect(result.device?.modelName, 'Galaxy S24');
    expect(result.device?.modelCode, 'SM-S921B');
    expect(result.device?.source, 'IMEI.info');
    final lookupRequest = requests.last;
    expect(lookupRequest.method, 'POST');
    expect(lookupRequest.url.path, '/api/inventory/identify');
    expect(jsonDecode(lookupRequest.body), {'imei': '490154203237518'});
    expect(
      lookupRequest.headers['authorization'],
      'Bearer test-session-token',
    );
  });

  test('keeps provider fallback status when Laravel reports lookup unavailable',
      () async {
    final apiClient = JakStoreApiClient(
      baseUrl: 'https://jakstore.test/api',
      tokenStorage: _MemoryTokenStorage(),
      httpClient: MockClient((_) async => _response({
            'data': {
              'status': 'not_configured',
              'message': 'Pilih model secara manual.',
              'device': null,
            },
          })),
    );

    final result = await ApiDeviceIdentificationService(apiClient).identify(
      '490154203237518',
    );

    expect(result.status, DeviceIdentificationStatus.notConfigured);
    expect(result.message, 'Pilih model secara manual.');
    expect(result.device, isNull);
  });
}

http.Response _response(Map<String, Object?> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
