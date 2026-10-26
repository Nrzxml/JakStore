import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jakstore_admin/data/inventory_store.dart';
import 'package:jakstore_admin/models/inventory.dart';
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
  test('loads catalog, inventory, and server movement history', () async {
    final api = JakStoreApiClient(
      baseUrl: 'https://example.test/api',
      tokenStorage: _MemoryTokenStorage(),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/models') {
          return _response({
            'data': [
              {
                'id': 3,
                'brand_id': 2,
                'name': 'Galaxy S24 Ultra',
                'brand': {'name': 'Samsung'},
                'total_units': 1,
                'available_units': 1,
                'is_active': true,
              },
            ],
          });
        }
        if (path == '/api/variants') {
          return _response({
            'data': [
              {
                'id': 8,
                'device_model_id': 3,
                'color': 'Titanium Black',
                'ram': '12 GB',
                'storage': '512 GB',
                'sku': 'SAM-S24U-512',
                'is_active': true,
              },
            ],
          });
        }
        if (path == '/api/reports') {
          return _response({
            'data': {
              'recent_movements': [
                {
                  'id': 22,
                  'inventory_unit_id': 13,
                  'imei': '490154203237518',
                  'type': 'incoming',
                  'note': 'Penerimaan awal',
                  'created_at': '2026-10-20T09:30:00.000000Z',
                },
              ],
            },
          });
        }
        if (path == '/api/inventory') {
          return _response({
            'data': [
              {
                'id': 13,
                'product_variant_id': 8,
                'imei1': '490154203237518',
                'imei2': null,
                'status': 'available',
                'recorded_at': '2026-10-20T09:30:00.000000Z',
              },
            ],
            'meta': {'last_page': 1},
          });
        }
        return http.Response('', 404);
      }),
    );
    final store = InventoryStore(apiClient: api);

    await store.refreshFromApi();

    expect(store.models.single.displayName, 'Samsung Galaxy S24 Ultra');
    expect(store.models.single.totalUnits, 1);
    expect(store.variants.single.id, '8');
    expect(store.variants.single.modelId, '3');
    expect(store.variants.single.ram, '12 GB');
    expect(store.units.single.id, '13');
    expect(store.units.single.status, UnitStatus.available);
    expect(store.countStatus(UnitStatus.available), 1);
    expect(store.recentMovements.single.type, MovementType.incoming);
    expect(store.recentMovements.single.unitId, '13');
  });
}

http.Response _response(Map<String, Object?> body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
