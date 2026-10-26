enum UnitStatus { available, sold, service, damaged, returned }

enum MovementType { incoming, outgoing, statusChanged }

extension UnitStatusLabel on UnitStatus {
  String get label => switch (this) {
        UnitStatus.available => 'Tersedia',
        UnitStatus.sold => 'Terjual',
        UnitStatus.service => 'Servis',
        UnitStatus.damaged => 'Rusak',
        UnitStatus.returned => 'Retur',
      };
}

extension MovementTypeLabel on MovementType {
  String get label => switch (this) {
        MovementType.incoming => 'Barang masuk',
        MovementType.outgoing => 'Barang keluar',
        MovementType.statusChanged => 'Perubahan status',
      };
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.brand,
    required this.name,
    this.brandId,
    this.totalUnits = 0,
    this.active = true,
  });

  final String id;
  final String brand;
  final String name;
  final String? brandId;
  final int totalUnits;
  final bool active;

  String get displayName => '$brand $name';
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.modelId,
    required this.color,
    required this.storage,
    required this.sku,
    this.ram,
    this.archived = false,
  });

  final String id;
  final String modelId;
  final String color;
  final String? ram;
  final String storage;
  final String sku;
  final bool archived;
}

class PhoneUnit {
  const PhoneUnit({
    required this.id,
    required this.variantId,
    required this.imei1,
    required this.status,
    required this.recordedAt,
    this.imei2,
  });

  final String id;
  final String variantId;
  final String imei1;
  final String? imei2;
  final UnitStatus status;
  final DateTime recordedAt;

  PhoneUnit copyWith({UnitStatus? status}) => PhoneUnit(
        id: id,
        variantId: variantId,
        imei1: imei1,
        imei2: imei2,
        status: status ?? this.status,
        recordedAt: recordedAt,
      );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.unitId,
    required this.imei,
    required this.type,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String unitId;
  final String imei;
  final MovementType type;
  final DateTime createdAt;
  final String? note;
}

String maskImei(String imei) {
  if (imei.length <= 4) return imei;
  return '${List.filled(imei.length - 4, '•').join()}${imei.substring(imei.length - 4)}';
}
