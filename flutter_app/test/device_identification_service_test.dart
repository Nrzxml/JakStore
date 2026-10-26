import 'package:flutter_test/flutter_test.dart';
import 'package:jakstore_admin/services/device_identification_service.dart';

void main() {
  group('DeviceIdentificationResult', () {
    test('marks an identified result with missing fields as incomplete', () {
      final result = DeviceIdentificationResult.identified(
        const IdentifiedDevice(
          brand: ' ',
          modelName: 'Galaxy S',
          source: 'Test source',
        ),
      );

      expect(result.status, DeviceIdentificationStatus.incomplete);
      expect(result.device, isNull);
    });

    test('keeps a complete result and its source metadata', () {
      final result = DeviceIdentificationResult.identified(
        const IdentifiedDevice(
          brand: 'Samsung',
          modelName: 'Galaxy S',
          modelCode: 'SM-S',
          tac: '12345678',
          source: 'Licensed catalog',
        ),
      );

      expect(result.status, DeviceIdentificationStatus.identified);
      expect(result.device?.source, 'Licensed catalog');
      expect(result.device?.tac, '12345678');
    });
  });

  test('default service explicitly reports that lookup is not configured',
      () async {
    const service = UnconfiguredDeviceIdentificationService();

    final result = await service.identify('490154203237518');

    expect(result.status, DeviceIdentificationStatus.notConfigured);
    expect(result.device, isNull);
  });
}
