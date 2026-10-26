import 'package:flutter/foundation.dart';

import '../models/inventory.dart';
import '../services/jakstore_api_client.dart';
import '../utils/imei.dart';

export '../utils/imei.dart' show isValidImei;

class InventoryStore extends ChangeNotifier {
  InventoryStore({this.apiClient})
      : models = [
          const ProductModel(
            id: 'iphone-15-pro-max',
            brand: 'Apple',
            name: 'iPhone 15 Pro Max',
          ),
          const ProductModel(
            id: 'galaxy-s24-ultra',
            brand: 'Samsung',
            name: 'Galaxy S24 Ultra',
          ),
          const ProductModel(
            id: 'pixel-9-pro',
            brand: 'Google',
            name: 'Pixel 9 Pro',
          ),
          const ProductModel(
            id: 'xiaomi-14',
            brand: 'Xiaomi',
            name: 'Xiaomi 14',
          ),
        ],
        variants = [
          const ProductVariant(
            id: 'iphone-15-pro-max-256-natural',
            modelId: 'iphone-15-pro-max',
            color: 'Natural Titanium',
            storage: '256 GB',
            sku: 'APL-IP15PM-256',
          ),
          const ProductVariant(
            id: 'galaxy-s24-ultra-512-black',
            modelId: 'galaxy-s24-ultra',
            color: 'Titanium Black',
            storage: '512 GB',
            sku: 'SAM-S24U-512',
          ),
          const ProductVariant(
            id: 'pixel-9-pro-256-obsidian',
            modelId: 'pixel-9-pro',
            color: 'Obsidian',
            storage: '256 GB',
            sku: 'GGL-P9P-256',
          ),
          const ProductVariant(
            id: 'xiaomi-14-512-black',
            modelId: 'xiaomi-14',
            color: 'Midnight Black',
            storage: '512 GB',
            sku: 'XMI-14-512',
          ),
        ],
        units = [
          PhoneUnit(
            id: 'unit-001',
            variantId: 'iphone-15-pro-max-256-natural',
            imei1: '490154203237518',
            status: UnitStatus.available,
            recordedAt: DateTime(2026, 10, 20),
          ),
          PhoneUnit(
            id: 'unit-002',
            variantId: 'iphone-15-pro-max-256-natural',
            imei1: '356938035643809',
            status: UnitStatus.available,
            recordedAt: DateTime(2026, 10, 21),
          ),
          PhoneUnit(
            id: 'unit-003',
            variantId: 'galaxy-s24-ultra-512-black',
            imei1: '352099001761481',
            status: UnitStatus.available,
            recordedAt: DateTime(2026, 10, 22),
          ),
          PhoneUnit(
            id: 'unit-004',
            variantId: 'galaxy-s24-ultra-512-black',
            imei1: '490154203237526',
            status: UnitStatus.sold,
            recordedAt: DateTime(2026, 10, 19),
          ),
          PhoneUnit(
            id: 'unit-005',
            variantId: 'pixel-9-pro-256-obsidian',
            imei1: '356938035643817',
            status: UnitStatus.service,
            recordedAt: DateTime(2026, 10, 18),
          ),
          PhoneUnit(
            id: 'unit-006',
            variantId: 'xiaomi-14-512-black',
            imei1: '352099001761408',
            status: UnitStatus.available,
            recordedAt: DateTime(2026, 10, 22),
          ),
        ],
        movements = [
          StockMovement(
            id: 'move-001',
            unitId: 'unit-001',
            imei: '490154203237518',
            type: MovementType.incoming,
            createdAt: DateTime(2026, 10, 20, 9, 16),
            note: 'Stok awal',
          ),
          StockMovement(
            id: 'move-002',
            unitId: 'unit-002',
            imei: '356938035643809',
            type: MovementType.incoming,
            createdAt: DateTime(2026, 10, 21, 10, 30),
            note: 'Stok awal',
          ),
          StockMovement(
            id: 'move-003',
            unitId: 'unit-004',
            imei: '490154203237526',
            type: MovementType.outgoing,
            createdAt: DateTime(2026, 10, 22, 10, 42),
          ),
        ];

  final JakStoreApiClient? apiClient;
  final List<ProductModel> models;
  final List<ProductVariant> variants;
  final List<PhoneUnit> units;
  final List<StockMovement> movements;
  String? _syncWarning;

  String? takeSyncWarning() {
    final warning = _syncWarning;
    _syncWarning = null;
    return warning;
  }

  Future<void> refreshFromApi() async {
    final api = apiClient;
    if (api == null) return;

    final modelData = await api.get(
      '/models',
      query: {'active_only': 'false'},
    );
    final variantData = await api.get(
      '/variants',
      query: {'active_only': 'false'},
    );
    final reportData = await api.get('/reports');
    final remoteModels = _listOfMaps(modelData['items']);
    final remoteVariants = _listOfMaps(variantData['items']);

    models
      ..clear()
      ..addAll(remoteModels.map((item) {
        final brand = item['brand'];
        return ProductModel(
          id: item['id'].toString(),
          brand: brand is Map ? brand['name'].toString() : '',
          name: item['name'].toString(),
          brandId: item['brand_id']?.toString(),
          totalUnits: (item['total_units'] as num?)?.toInt() ?? 0,
          active: item['is_active'] == true,
        );
      }));
    variants
      ..clear()
      ..addAll(remoteVariants.map((item) => ProductVariant(
            id: item['id'].toString(),
            modelId: item['device_model_id'].toString(),
            color: item['color'].toString(),
            ram: item['ram']?.toString(),
            storage: item['storage'].toString(),
            sku: item['sku'].toString(),
            archived: item['is_active'] != true,
          )));

    units.clear();
    var page = 1;
    while (true) {
      final pageData = await api.get(
        '/inventory',
        query: {'per_page': '100', 'page': '$page'},
      );
      final items = _listOfMaps(pageData['items']);
      units.addAll(items.map(_phoneUnitFromApi));
      final meta = pageData['meta'];
      if (meta is! Map || page >= (meta['last_page'] as num? ?? 1)) break;
      page++;
    }

    movements
      ..clear()
      ..addAll(_listOfMaps(reportData['recent_movements']).map((item) {
        final date = DateTime.tryParse(item['created_at']?.toString() ?? '');
        return StockMovement(
          id: item['id'].toString(),
          unitId: item['inventory_unit_id'].toString(),
          imei: item['imei'].toString(),
          type: _movementType(item['type']),
          createdAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
          note: item['note']?.toString(),
        );
      }));
    notifyListeners();
  }

  Future<String?> addUnitOnline({
    required String variantId,
    required String imei1,
    String? imei2,
    String? note,
    UnitStatus status = UnitStatus.available,
  }) async {
    final api = apiClient;
    if (api == null)
      return addUnit(
        variantId: variantId,
        imei1: imei1,
        imei2: imei2,
        note: note,
        status: status,
      );
    try {
      final unit = await api.post('/inventory', body: {
        'product_variant_id': int.parse(variantId),
        'imei1': imei1.trim(),
        if (imei2 != null && imei2.trim().isNotEmpty) 'imei2': imei2.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'status': status.name,
      });
      _upsertUnitFromApi(unit, MovementType.incoming, note: note);
      await _refreshAfterMutation();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> scanOutgoingOnline(String imei, {String? note}) async {
    final api = apiClient;
    if (api == null) return scanOutgoing(imei, note: note);
    try {
      final unit = await api.post('/inventory/scan-outgoing', body: {
        'imei': imei.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      _upsertUnitFromApi(unit, MovementType.outgoing, note: note);
      await _refreshAfterMutation();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> updateUnitStatusOnline(
    String unitId,
    UnitStatus nextStatus,
  ) async {
    final api = apiClient;
    if (api == null) return updateUnitStatus(unitId, nextStatus);
    try {
      final unit = await api.patch(
        '/inventory/$unitId/status',
        body: {'status': nextStatus.name},
      );
      _upsertUnitFromApi(unit, MovementType.statusChanged);
      await _refreshAfterMutation();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<ProductModel> createCatalogModel({
    required String brand,
    required String name,
    String? modelCode,
  }) async {
    final api = apiClient;
    if (api == null) {
      throw const ApiException(
        'Penambahan katalog hanya tersedia saat terhubung ke server.',
      );
    }
    final response = await api.post('/catalog/models', body: {
      'brand': brand.trim(),
      'name': name.trim(),
      if (modelCode != null && modelCode.trim().isNotEmpty)
        'model_code': modelCode.trim(),
    });
    final brandData = response['brand'];
    final model = ProductModel(
      id: response['id'].toString(),
      brand: brandData is Map ? brandData['name'].toString() : brand.trim(),
      name: response['name'].toString(),
      brandId: response['brand_id']?.toString(),
      totalUnits: (response['total_units'] as num?)?.toInt() ?? 0,
      active: response['is_active'] == true,
    );
    final existingIndex = models.indexWhere((item) => item.id == model.id);
    if (existingIndex < 0) {
      models.add(model);
    } else {
      models[existingIndex] = model;
    }
    notifyListeners();
    return model;
  }

  Future<ProductVariant> createCatalogVariant({
    required String modelId,
    required String color,
    required String ram,
    required String storage,
  }) async {
    final api = apiClient;
    if (api == null) {
      throw const ApiException(
        'Penambahan katalog hanya tersedia saat terhubung ke server.',
      );
    }
    final response = await api.post('/variants', body: {
      'device_model_id': int.parse(modelId),
      'color': color.trim(),
      'ram': ram.trim(),
      'storage': storage.trim(),
    });
    final variant = ProductVariant(
      id: response['id'].toString(),
      modelId: response['device_model_id'].toString(),
      color: response['color'].toString(),
      ram: response['ram']?.toString(),
      storage: response['storage'].toString(),
      sku: response['sku'].toString(),
      archived: response['is_active'] != true,
    );
    final existingIndex = variants.indexWhere((item) => item.id == variant.id);
    if (existingIndex < 0) {
      variants.add(variant);
    } else {
      variants[existingIndex] = variant;
    }
    notifyListeners();
    return variant;
  }

  void _upsertUnitFromApi(
    Map<String, dynamic> item,
    MovementType movementType, {
    String? note,
  }) {
    final unit = _phoneUnitFromApi(item);
    final index = units.indexWhere((existing) => existing.id == unit.id);
    if (index < 0) {
      units.insert(0, unit);
    } else {
      units[index] = unit;
    }
    final now = DateTime.now();
    movements.insert(
      0,
      StockMovement(
        id: 'pending-${unit.id}-${now.microsecondsSinceEpoch}',
        unitId: unit.id,
        imei: unit.imei1,
        type: movementType,
        createdAt: now,
        note: note,
      ),
    );
    notifyListeners();
  }

  Future<void> _refreshAfterMutation() async {
    try {
      await refreshFromApi();
      _syncWarning = null;
    } on ApiException catch (error) {
      _syncWarning =
          'Perubahan sudah tersimpan, tetapi data terbaru gagal dimuat: '
          '${error.message}';
      notifyListeners();
    }
  }

  PhoneUnit _phoneUnitFromApi(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['recorded_at']?.toString() ?? '');
    return PhoneUnit(
      id: item['id'].toString(),
      variantId: item['product_variant_id'].toString(),
      imei1: item['imei1'].toString(),
      imei2: item['imei2']?.toString(),
      status: UnitStatus.values.firstWhere(
        (status) => status.name == item['status'],
        orElse: () => UnitStatus.available,
      ),
      recordedAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  MovementType _movementType(dynamic value) => MovementType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => MovementType.statusChanged,
      );

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<PhoneUnit> unitsFor(String variantId) =>
      units.where((unit) => unit.variantId == variantId).toList();

  List<PhoneUnit> unitsForModel(String modelId) {
    final variantIds = variants
        .where((variant) => variant.modelId == modelId)
        .map((variant) => variant.id);
    return units
        .where((unit) => variantIds.contains(unit.variantId))
        .toList(growable: false);
  }

  String variantDescription(ProductVariant variant) {
    final memory = variant.ram == null || variant.ram!.isEmpty
        ? variant.storage
        : '${variant.ram} / ${variant.storage}';
    return '${variant.color} • $memory';
  }

  ProductVariant? variantFor(String id) {
    for (final variant in variants) {
      if (variant.id == id) return variant;
    }
    return null;
  }

  ProductModel? modelFor(String id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }

  ProductModel? modelByIdentity({
    required String brand,
    required String modelName,
  }) {
    final normalizedBrand = _normalizeCatalogText(brand);
    final normalizedName = _normalizeCatalogText(modelName);
    for (final model in models) {
      if (_normalizeCatalogText(model.brand) == normalizedBrand &&
          _normalizeCatalogText(model.name) == normalizedName) {
        return model;
      }
    }
    return null;
  }

  List<ProductVariant> variantsForModel(String modelId) => variants
      .where((variant) => variant.modelId == modelId && !variant.archived)
      .toList(growable: false);

  String displayNameFor(ProductVariant variant) =>
      modelFor(variant.modelId)?.displayName ?? 'Model tidak ditemukan';

  PhoneUnit? unitByImei(String imei) {
    final normalized = imei.trim();
    for (final unit in units) {
      if (unit.imei1 == normalized || unit.imei2 == normalized) return unit;
    }
    return null;
  }

  PhoneUnit? unitById(String id) {
    for (final unit in units) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  int countStatus(UnitStatus status) =>
      units.where((unit) => unit.status == status).length;

  int availableFor(String variantId) => units
      .where(
        (unit) =>
            unit.variantId == variantId && unit.status == UnitStatus.available,
      )
      .length;

  int get incomingToday => _movementsToday
      .where((move) => move.type == MovementType.incoming)
      .length;

  int get outgoingToday => _movementsToday
      .where((move) => move.type == MovementType.outgoing)
      .length;

  List<StockMovement> get recentMovements =>
      movements.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Iterable<StockMovement> get _movementsToday {
    final now = DateTime.now();
    return movements.where(
      (move) =>
          move.createdAt.year == now.year &&
          move.createdAt.month == now.month &&
          move.createdAt.day == now.day,
    );
  }

  String? addUnit({
    required String variantId,
    required String imei1,
    String? imei2,
    String? note,
    UnitStatus status = UnitStatus.available,
  }) {
    final first = imei1.trim();
    final second = imei2?.trim();
    if (!isValidImei(first)) return 'IMEI 1 harus 15 digit dan lolos validasi.';
    if (second != null && second.isNotEmpty && !isValidImei(second)) {
      return 'IMEI 2 harus kosong atau berisi 15 digit yang valid.';
    }
    if (second == first) return 'IMEI 1 dan IMEI 2 tidak boleh sama.';
    if (unitByImei(first) != null ||
        (second != null && second.isNotEmpty && unitByImei(second) != null)) {
      return 'IMEI sudah terdaftar pada unit lain.';
    }
    if (variantFor(variantId) == null) return 'Varian produk tidak ditemukan.';
    if (status == UnitStatus.sold) {
      return 'Status terjual hanya dapat dicatat melalui alur barang keluar.';
    }

    final id = 'unit-${DateTime.now().microsecondsSinceEpoch}';
    final unit = PhoneUnit(
      id: id,
      variantId: variantId,
      imei1: first,
      imei2: second == null || second.isEmpty ? null : second,
      status: status,
      recordedAt: DateTime.now(),
    );
    units.add(unit);
    _recordMovement(unit, MovementType.incoming, note: note);
    notifyListeners();
    return null;
  }

  String? scanOutgoing(String imei, {String? note}) {
    final unit = unitByImei(imei);
    if (unit == null)
      return 'IMEI tidak ditemukan. Periksa kode lalu coba lagi.';
    if (unit.status != UnitStatus.available) {
      return 'Unit berstatus ${unit.status.label.toLowerCase()} dan tidak dapat dikeluarkan.';
    }
    final index = units.indexWhere((item) => item.id == unit.id);
    units[index] = unit.copyWith(status: UnitStatus.sold);
    _recordMovement(units[index], MovementType.outgoing, note: note);
    notifyListeners();
    return null;
  }

  String? updateUnitStatus(String unitId, UnitStatus nextStatus) {
    final index = units.indexWhere((unit) => unit.id == unitId);
    if (index < 0) return 'Unit tidak ditemukan.';
    final current = units[index];
    if (current.status == nextStatus) return null;
    if (current.status == UnitStatus.sold || nextStatus == UnitStatus.sold) {
      return 'Status terjual hanya dapat dicatat melalui scan barang keluar.';
    }
    units[index] = current.copyWith(status: nextStatus);
    _recordMovement(units[index], MovementType.statusChanged);
    notifyListeners();
    return null;
  }

  void _recordMovement(PhoneUnit unit, MovementType type, {String? note}) {
    movements.add(
      StockMovement(
        id: 'move-${DateTime.now().microsecondsSinceEpoch}',
        unitId: unit.id,
        imei: unit.imei1,
        type: type,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
  }
}

String _normalizeCatalogText(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
