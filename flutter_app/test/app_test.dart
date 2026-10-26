import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jakstore_admin/data/inventory_store.dart';
import 'package:jakstore_admin/main.dart';
import 'package:jakstore_admin/models/inventory.dart';
import 'package:jakstore_admin/services/device_identification_service.dart';

void main() {
  testWidgets('opens the admin dashboard and navigates between core screens',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(JakStoreAdminApp(store: store));

    expect(find.text('Ringkasan gudang'), findsOneWidget);
    expect(find.text('Stok tersedia'), findsOneWidget);
    expect(find.text('User'), findsNothing);

    await tester.tap(find.text('Inventori'));
    await tester.pumpAndSettle();
    expect(find.text('Stok barang'), findsOneWidget);
    expect(find.text('IMEI 1'), findsNothing);

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    expect(find.text('Scan IMEI'), findsOneWidget);
    expect(find.text('Scan dengan kamera'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '490154203237518');
    await tester.ensureVisible(find.text('Konfirmasi scan'));
    await tester.tap(find.text('Konfirmasi scan'));
    await tester.pumpAndSettle();
    expect(store.countStatus(UnitStatus.available), 3);
    expect(store.countStatus(UnitStatus.sold), 2);

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan stok'), findsOneWidget);
    expect(find.text('Stok per model'), findsOneWidget);
  });

  testWidgets('inventory groups units by model and masks IMEI until detail',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(JakStoreAdminApp(store: store));

    await tester.tap(find.text('Inventori'));
    await tester.pumpAndSettle();
    expect(find.text('Apple iPhone 15 Pro Max'), findsOneWidget);
    expect(find.text('2 unit fisik'), findsNWidgets(2));
    expect(find.text('APL-IP15PM-256'), findsNothing);
    expect(find.text('490154203237518'), findsNothing);

    await tester.tap(find.text('Apple iPhone 15 Pro Max'));
    await tester.pumpAndSettle();
    expect(find.text('Detail model'), findsOneWidget);
    expect(find.text('Natural Titanium • 256 GB'), findsOneWidget);

    await tester.tap(find.text('Natural Titanium • 256 GB'));
    await tester.pumpAndSettle();
    expect(find.text('Detail varian'), findsOneWidget);
    expect(find.text('•••••••••••7518'), findsOneWidget);
    expect(find.text('490154203237518'), findsNothing);

    await tester.tap(find.text('•••••••••••7518'));
    await tester.pumpAndSettle();
    expect(find.text('Detail unit'), findsOneWidget);
    expect(find.text('IMEI 1'), findsOneWidget);
    expect(find.text('490154203237518'), findsOneWidget);
  });

  testWidgets('shows duplicate IMEI feedback on the add-unit form',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(JakStoreAdminApp(store: store));

    await tester.tap(find.text('Inventori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah unit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      '490154203237518',
    );
    await tester.ensureVisible(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pumpAndSettle();

    expect(find.text('IMEI sudah terdaftar pada unit lain.'), findsOneWidget);
    expect(store.units, hasLength(6));
  });

  testWidgets('rejects an IMEI 2 already assigned to another unit',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(JakStoreAdminApp(store: store));

    await tester.tap(find.text('Inventori'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah unit'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '490154203237542');
    await tester.enterText(fields.at(1), '356938035643809');
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pumpAndSettle();

    expect(find.text('IMEI sudah terdaftar pada unit lain.'), findsOneWidget);
    expect(store.units, hasLength(6));
  });

  testWidgets('prefills an unknown checked IMEI in the add-unit form',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(JakStoreAdminApp(store: store));

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek IMEI').first);
    await tester.pumpAndSettle();
    expect(find.text('Pengecekan unit'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '490154203237542',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('scan-imei-input')))
          .controller!
          .text,
      '490154203237542',
    );

    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Cari unit'));
    await tester.tap(find.text('Cari unit'));
    await tester.pumpAndSettle();
    final registerButton = find.text('Simpan');
    await tester.drag(
      find.byKey(const ValueKey('scan-screen-list')),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(registerButton, findsOneWidget);
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump(const Duration(milliseconds: 500));

    final imeiField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(imeiField.controller!.text, '490154203237542');
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.units, hasLength(7));
    expect(store.unitByImei('490154203237542'), isNotNull);
  });

  testWidgets('shows the matching unit when an IMEI 2 is entered',
      (tester) async {
    final store = InventoryStore();
    final error = store.addUnit(
      variantId: store.variants.first.id,
      imei1: '490154203237542',
      imei2: '351756051523993',
    );
    expect(error, isNull);

    await tester.pumpWidget(JakStoreAdminApp(store: store));
    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek IMEI').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '351756051523993',
    );
    await tester.pump();
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.dragFrom(const Offset(400, 500), const Offset(0, -350));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Unit ditemukan'), findsOneWidget);
    expect(find.text('Barcode cocok dengan IMEI 2 dari unit yang sama.'),
        findsOneWidget);
    expect(find.text('IMEI 2: 351756051523993'), findsOneWidget);
    expect(store.units, hasLength(7));
  });

  testWidgets('identifies a model and preselects its catalog model on input',
      (tester) async {
    final store = InventoryStore();
    final service = FakeDeviceIdentificationService(
      DeviceIdentificationResult.identified(
        const IdentifiedDevice(
          brand: 'Apple',
          modelName: 'iPhone 15 Pro Max',
          modelCode: 'A3108',
          source: 'Test catalog',
        ),
      ),
    );
    await tester.pumpWidget(
      JakStoreAdminApp(
        store: store,
        deviceIdentificationService: service,
      ),
    );

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek IMEI').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '490154203237542',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Cari unit'));
    await tester.tap(find.text('Cari unit'));
    await tester.pumpAndSettle();

    expect(find.text('Informasi perangkat ditemukan'), findsOneWidget);
    expect(find.text('Kode model'), findsOneWidget);
    expect(
        find.textContaining('Cocok dengan katalog JakStore'), findsOneWidget);
    expect(service.lastImei, '490154203237542');
    expect(store.units, hasLength(6));

    await tester.drag(
      find.byKey(const ValueKey('scan-screen-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.textContaining('Model teridentifikasi: Apple iPhone 15 Pro Max'),
        findsOneWidget);
    final imeiField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(imeiField.controller!.text, '490154203237542');
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(
      find.byKey(const ValueKey('add-unit-form-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pumpAndSettle();

    final added = store.unitByImei('490154203237542');
    expect(added, isNotNull);
    expect(added!.variantId, 'iphone-15-pro-max-256-natural');
  });

  testWidgets('keeps unknown catalog models available for manual selection',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(
      JakStoreAdminApp(
        store: store,
        deviceIdentificationService: FakeDeviceIdentificationService(
          DeviceIdentificationResult.identified(
            const IdentifiedDevice(
              brand: 'Samsung',
              modelName: 'Galaxy A56 5G',
              modelCode: 'SM-A566B',
              source: 'Test catalog',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek IMEI').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '490154203237542',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Cari unit'));
    await tester.tap(find.text('Cari unit'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Model ini belum cocok persis dengan katalog'),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const ValueKey('scan-screen-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Model HP'), findsOneWidget);
    expect(
      find.textContaining('Model teridentifikasi: Samsung Galaxy A56 5G'),
      findsNothing,
    );
    expect(store.units, hasLength(6));

    await tester.tap(find.byKey(const ValueKey('add-unit-model-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samsung Galaxy S24 Ultra').last);
    await tester.pumpAndSettle();
    expect(find.text('Titanium Black • 512 GB'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      '490154203237542',
    );
    await tester.ensureVisible(find.text('Simpan Barang'));
    await tester.tap(find.text('Simpan Barang'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi model'), findsOneWidget);
    await tester.tap(find.text('Tetap lanjutkan'));
    await tester.pumpAndSettle();
    expect(
      store.unitByImei('490154203237542')?.variantId,
      'galaxy-s24-ultra-512-black',
    );
  });

  testWidgets('blocks duplicate registration when lookup returns a known unit',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(
      JakStoreAdminApp(
        store: store,
        deviceIdentificationService: FakeDeviceIdentificationService(
          DeviceIdentificationResult.knownUnit(
            message: 'IMEI ini sudah tercatat.',
            unitId: 'unit-known-1',
            status: 'available',
            brand: 'Samsung',
            modelName: 'Galaxy S24 Ultra',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '490154203237542',
    );
    await tester.ensureVisible(find.text('Identifikasi IMEI'));
    await tester.tap(find.text('Identifikasi IMEI'));
    await tester.pumpAndSettle();

    expect(find.text('IMEI sudah terdaftar'), findsOneWidget);
    expect(find.text('Status unit'), findsOneWidget);
    expect(find.text('Simpan'), findsNothing);
    expect(store.units, hasLength(6));
  });

  testWidgets('shows lookup errors and preserves the IMEI for manual input',
      (tester) async {
    final store = InventoryStore();
    await tester.pumpWidget(
      JakStoreAdminApp(
        store: store,
        deviceIdentificationService: FakeDeviceIdentificationService(
          null,
          error: TimeoutException('lookup timed out'),
        ),
      ),
    );

    await tester.tap(find.text('Scan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cek IMEI').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('scan-imei-input')),
      '490154203237542',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Cari unit'));
    await tester.tap(find.text('Cari unit'));
    await tester.pumpAndSettle();

    expect(find.text('Model belum teridentifikasi'), findsOneWidget);
    expect(find.text('Coba identifikasi lagi'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('scan-screen-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final imeiField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(imeiField.controller!.text, '490154203237542');
  });
}

class FakeDeviceIdentificationService implements DeviceIdentificationService {
  FakeDeviceIdentificationService(this.result, {this.error});

  final DeviceIdentificationResult? result;
  final Exception? error;
  String? lastImei;

  @override
  Future<DeviceIdentificationResult> identify(String imei) async {
    lastImei = imei;
    if (error != null) throw error!;
    return result!;
  }
}
