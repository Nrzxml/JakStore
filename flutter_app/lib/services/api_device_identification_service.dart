import 'package:jakstore_admin/services/device_identification_service.dart';

import 'jakstore_api_client.dart';

class ApiDeviceIdentificationService implements DeviceIdentificationService {
  const ApiDeviceIdentificationService(this.apiClient);

  final JakStoreApiClient apiClient;

  @override
  Future<DeviceIdentificationResult> identify(String imei) async {
    try {
      final data = await apiClient.post(
        '/inventory/identify',
        body: {'imei': imei},
      );
      final status = data['status'];
      final message = data['message'] is String
          ? data['message'] as String
          : 'Informasi perangkat tidak tersedia.';
      final device = data['device'];
      if (status == 'identified' && device is Map<String, dynamic>) {
        return DeviceIdentificationResult.identified(
          IdentifiedDevice(
            brand: device['brand']?.toString() ?? '',
            modelName: device['model_name']?.toString() ?? '',
            modelCode: device['model_code']?.toString(),
            tac: device['tac']?.toString(),
            source: device['source']?.toString() ?? 'backend',
          ),
        );
      }
      if (status == 'known_unit') {
        final unit = data['unit'];
        final variant = unit is Map<String, dynamic> ? unit['variant'] : null;
        final model = variant is Map<String, dynamic> ? variant['model'] : null;
        final brand = model is Map<String, dynamic> ? model['brand'] : null;
        final modelName = model is Map<String, dynamic> ? model['name'] : null;
        return DeviceIdentificationResult.knownUnit(
          message: 'IMEI ini sudah tercatat sebagai unit inventori.',
          unitId: unit is Map<String, dynamic> ? unit['id']?.toString() : null,
          status: unit is Map<String, dynamic>
              ? unit['status']?.toString()
              : null,
          brand: brand is Map<String, dynamic> ? brand['name']?.toString() : null,
          modelName: modelName?.toString(),
        );
      }
      if (status == 'not_found') {
        return DeviceIdentificationResult.notFound(message);
      }
      if (status == 'incomplete') {
        return DeviceIdentificationResult.incomplete(message);
      }
      if (status == 'not_configured') {
        return DeviceIdentificationResult.notConfigured(message);
      }
      return DeviceIdentificationResult.unavailable(message);
    } on ApiException catch (error) {
      if (error.statusCode == 422) {
        return DeviceIdentificationResult.incomplete(error.message);
      }
      return DeviceIdentificationResult.unavailable(error.message);
    }
  }
}
