import 'package:flutter_test/flutter_test.dart';
import 'package:jakstore_admin/data/inventory_store.dart';
import 'package:jakstore_admin/models/inventory.dart';

void main() {
  group('IMEI validation', () {
    test('accepts a valid 15-digit IMEI', () {
      expect(isValidImei('490154203237518'), isTrue);
    });

    test('rejects malformed and invalid-check-digit IMEIs', () {
      expect(isValidImei('49015420323751'), isFalse);
      expect(isValidImei('490154203237519'), isFalse);
    });
  });

  group('InventoryStore', () {
    late InventoryStore store;

    setUp(() => store = InventoryStore());

    test('counts physical units, not product variants, as stock', () {
      expect(store.units.length, 6);
      expect(store.countStatus(UnitStatus.available), 4);
      expect(store.models.length, 4);
      expect(store.variants.length, 4);
    });

    test('rejects duplicate IMEI and leaves inventory unchanged', () {
      final originalCount = store.units.length;
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237518',
      );

      expect(error, contains('sudah terdaftar'));
      expect(store.units, hasLength(originalCount));
    });

    test('incoming unit creates one available unit and a movement', () {
      final originalCount = store.units.length;
      final originalMovements = store.movements.length;
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
      );

      expect(error, isNull);
      expect(store.units, hasLength(originalCount + 1));
      expect(store.countStatus(UnitStatus.available), 5);
      expect(store.movements, hasLength(originalMovements + 1));
      expect(store.movements.last.type, MovementType.incoming);
    });

    test('outgoing unit changes availability and cannot be scanned twice', () {
      final error = store.scanOutgoing('490154203237518');

      expect(error, isNull);
      expect(store.countStatus(UnitStatus.available), 3);
      expect(store.countStatus(UnitStatus.sold), 2);
      expect(
        store.scanOutgoing('490154203237518'),
        contains('tidak dapat dikeluarkan'),
      );
    });

    test('sold status cannot bypass the outgoing scan flow', () {
      final error = store.updateUnitStatus('unit-001', UnitStatus.sold);

      expect(error, contains('scan barang keluar'));
      expect(store.countStatus(UnitStatus.available), 4);
      expect(store.countStatus(UnitStatus.sold), 1);
    });

    test('IMEI 2 identifies the same physical unit', () {
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
        imei2: '356938035643809',
      );

      expect(error, contains('sudah terdaftar'));
      expect(store.units, hasLength(6));
    });

    test('counts an IMEI 1 and IMEI 2 as one unit in the model group', () {
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
        imei2: '351756051523993',
      );

      expect(error, isNull);
      expect(store.unitsForModel(store.variants.first.modelId), hasLength(3));
      expect(store.units, hasLength(7));
    });

    test('masks list IMEIs and leaves full values for unit detail', () {
      expect(maskImei('490154203237518'), '•••••••••••7518');
      expect(store.unitByImei('490154203237518')?.imei1, '490154203237518');
    });

    test('finds known IMEI 1 and returns null for an unknown IMEI', () {
      expect(store.unitByImei('490154203237518')?.id, 'unit-001');
      expect(store.unitByImei('490154203237542'), isNull);
    });

    test('matches an identified device to the exact catalog model', () {
      expect(
        store
            .modelByIdentity(
              brand: 'APPLE',
              modelName: 'iPhone 15 Pro Max',
            )
            ?.id,
        'iphone-15-pro-max',
      );
      expect(
        store.modelByIdentity(
          brand: 'Apple',
          modelName: 'iPhone 15 Pro',
        ),
        isNull,
      );
    });

    test('adds a unit with a non-sold initial status', () {
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
        status: UnitStatus.service,
      );

      expect(error, isNull);
      expect(store.unitByImei('490154203237542')?.status, UnitStatus.service);
      expect(store.countStatus(UnitStatus.available), 4);
      expect(store.countStatus(UnitStatus.service), 2);
    });

    test('finds a unit by its IMEI 2 without adding another stock unit', () {
      final error = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
        imei2: '351756051523993',
      );
      expect(error, isNull);

      final originalUnitCount = store.units.length;
      final found = store.unitByImei('351756051523993');

      expect(found, isNotNull);
      expect(found!.imei1, '490154203237542');
      expect(found.imei2, '351756051523993');
      expect(store.units, hasLength(originalUnitCount));
    });

    test('rejects processing the same scanned IMEI twice', () {
      final firstResult = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
      );
      final countAfterFirstScan = store.units.length;
      final secondResult = store.addUnit(
        variantId: store.variants.first.id,
        imei1: '490154203237542',
      );

      expect(firstResult, isNull);
      expect(secondResult, contains('sudah terdaftar'));
      expect(store.units, hasLength(countAfterFirstScan));
    });
  });
}
