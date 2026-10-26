enum DeviceIdentificationStatus {
  identified,
  knownUnit,
  notFound,
  unavailable,
  incomplete,
  notConfigured,
}

class IdentifiedDevice {
  const IdentifiedDevice({
    required this.brand,
    required this.modelName,
    required this.source,
    this.modelCode,
    this.tac,
  });

  final String brand;
  final String modelName;
  final String? modelCode;
  final String? tac;
  final String source;
}

class DeviceIdentificationResult {
  const DeviceIdentificationResult._({
    required this.status,
    required this.message,
    this.device,
    this.knownUnitId,
    this.knownUnitStatus,
  });

  factory DeviceIdentificationResult.identified(IdentifiedDevice device) {
    if (device.brand.trim().isEmpty ||
        device.modelName.trim().isEmpty ||
        device.source.trim().isEmpty) {
      return DeviceIdentificationResult.incomplete(
        'Layanan mengembalikan informasi model yang tidak lengkap. '
        'Pilih model secara manual.',
      );
    }
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.identified,
      message: 'Informasi model berhasil ditemukan.',
      device: device,
    );
  }

  factory DeviceIdentificationResult.notFound(String message) {
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.notFound,
      message: message,
    );
  }

  factory DeviceIdentificationResult.unavailable(String message) {
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.unavailable,
      message: message,
    );
  }

  factory DeviceIdentificationResult.incomplete(String message) {
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.incomplete,
      message: message,
    );
  }

  factory DeviceIdentificationResult.notConfigured(String message) {
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.notConfigured,
      message: message,
    );
  }

  factory DeviceIdentificationResult.knownUnit({
    required String message,
    String? unitId,
    String? status,
    String? brand,
    String? modelName,
  }) {
    final device = brand == null || modelName == null
        ? null
        : IdentifiedDevice(
            brand: brand,
            modelName: modelName,
            source: 'Inventori JakStore',
          );
    return DeviceIdentificationResult._(
      status: DeviceIdentificationStatus.knownUnit,
      message: message,
      device: device,
      knownUnitId: unitId,
      knownUnitStatus: status,
    );
  }

  final DeviceIdentificationStatus status;
  final String message;
  final IdentifiedDevice? device;
  final String? knownUnitId;
  final String? knownUnitStatus;
}

abstract interface class DeviceIdentificationService {
  /// Implementations should apply a network timeout and must not log full IMEIs.
  Future<DeviceIdentificationResult> identify(String imei);
}

class UnconfiguredDeviceIdentificationService
    implements DeviceIdentificationService {
  const UnconfiguredDeviceIdentificationService();

  @override
  Future<DeviceIdentificationResult> identify(String imei) async {
    return DeviceIdentificationResult.notConfigured(
      'Aplikasi belum terhubung ke backend untuk lookup otomatis. '
      'Hubungkan ke API Laravel atau pilih model secara manual.',
    );
  }
}
