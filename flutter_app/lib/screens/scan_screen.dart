import 'package:flutter/material.dart';

import '../data/inventory_store.dart';
import '../models/inventory.dart';
import '../services/device_identification_service.dart';
import '../utils/imei.dart';
import '../widgets/status_badge.dart';
import 'imei_camera_scanner_screen.dart';

enum _ScanMode { incoming, outgoing, lookup }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.store,
    required this.deviceIdentificationService,
    required this.onOpenUnit,
    required this.onRegisterUnknownImei,
    super.key,
  });

  final InventoryStore store;
  final DeviceIdentificationService deviceIdentificationService;
  final ValueChanged<PhoneUnit> onOpenUnit;
  final Future<bool?> Function(
    String imei, {
    String? initialModelId,
    String? identifiedModelId,
    String? identifiedModelName,
  }) onRegisterUnknownImei;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final imeiController = TextEditingController();
  final noteController = TextEditingController();
  _ScanMode mode = _ScanMode.outgoing;
  PhoneUnit? foundUnit;
  String? cameraScannedImei;
  bool registeringScannedImei = false;
  bool identifyingDevice = false;
  String? identificationImei;
  DeviceIdentificationResult? identificationResult;
  int identificationRequestId = 0;

  @override
  void dispose() {
    imeiController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final scannedUnit = imeiController.text.trim().isEmpty
            ? foundUnit
            : widget.store.unitByImei(imeiController.text);
        final variant = scannedUnit == null
            ? null
            : widget.store.variantFor(scannedUnit.variantId);

        return ListView(
          key: const ValueKey('scan-screen-list'),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: [
            const Text(
              'Scan IMEI',
              style: TextStyle(
                color: Color(0xFF10172A),
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Catat pergerakan unit berdasarkan IMEI.',
              style: TextStyle(color: Color(0xFF778196)),
            ),
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECF3),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  _ModeButton(
                    label: 'Masuk',
                    selected: mode == _ScanMode.incoming,
                    onTap: () => _setMode(_ScanMode.incoming),
                  ),
                  _ModeButton(
                    label: 'Keluar',
                    selected: mode == _ScanMode.outgoing,
                    onTap: () => _setMode(_ScanMode.outgoing),
                  ),
                  _ModeButton(
                    label: 'Cek IMEI',
                    selected: mode == _ScanMode.lookup,
                    onTap: () => _setMode(_ScanMode.lookup),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openCameraScanner,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan dengan kamera'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A2A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Arahkan kamera belakang ke barcode IMEI. Input manual tersedia sebagai alternatif.',
              style: TextStyle(color: Color(0xFF778196), fontSize: 11),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF10172A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFFFF8A58),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          mode == _ScanMode.lookup
                              ? 'Pengecekan unit'
                              : mode == _ScanMode.incoming
                                  ? 'Pencatatan barang masuk'
                                  : 'Pencatatan barang keluar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Masukkan IMEI secara manual jika barcode sulit dipindai atau kamera tidak tersedia.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('scan-imei-input'),
                    controller: imeiController,
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                    style: const TextStyle(
                      color: Color(0xFF10172A),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'IMEI unit',
                      hintText: 'Masukkan 15 digit IMEI',
                      counterText: '',
                      prefixIcon: Icon(Icons.phone_iphone),
                    ),
                    onChanged: _onImeiChanged,
                    onSubmitted: (_) => _lookup(),
                  ),
                  if (mode == _ScanMode.incoming &&
                      widget.store.variants.isEmpty) ...[
                    const SizedBox(height: 12),
                    const _InfoMessage(
                      icon: Icons.info_outline,
                      message:
                          'Tambahkan katalog model dan varian sebelum mencatat barang masuk.',
                    ),
                  ],
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: Icon(
                        mode != _ScanMode.outgoing
                            ? Icons.search
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        mode == _ScanMode.lookup
                            ? 'Cari unit'
                            : mode == _ScanMode.incoming
                                ? 'Identifikasi IMEI'
                                : 'Konfirmasi scan',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: mode == _ScanMode.incoming
                            ? const Color(0xFF16845B)
                            : const Color(0xFFFF6A2A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (mode != _ScanMode.outgoing &&
                scannedUnit != null &&
                variant != null) ...[
              const SizedBox(height: 14),
              _UnitLookupCard(
                unit: scannedUnit,
                variant: variant,
                displayName: widget.store.displayNameFor(variant),
                matchedImei: imeiController.text.trim(),
                onOpenUnit: () => widget.onOpenUnit(scannedUnit),
              ),
            ],
            if (mode != _ScanMode.outgoing &&
                scannedUnit == null &&
                identifyingDevice &&
                identificationImei == imeiController.text.trim()) ...[
              const SizedBox(height: 14),
              _DeviceIdentificationProgress(imei: imeiController.text.trim()),
            ],
            if (mode != _ScanMode.outgoing &&
                scannedUnit == null &&
                !identifyingDevice &&
                identificationImei == imeiController.text.trim() &&
                identificationResult != null) ...[
              const SizedBox(height: 14),
              _DeviceIdentificationCard(
                imei: imeiController.text.trim(),
                result: identificationResult!,
                catalogModel: _matchedCatalogModel(identificationResult),
                onContinue:
                    registeringScannedImei ? null : _registerUnknownImei,
                onRetry: identificationResult!.status ==
                            DeviceIdentificationStatus.notConfigured ||
                        identificationResult!.status ==
                            DeviceIdentificationStatus.knownUnit
                    ? null
                    : () => _identifyDevice(imeiController.text.trim()),
              ),
            ],
            if (mode != _ScanMode.outgoing &&
                imeiController.text.trim().isNotEmpty &&
                scannedUnit == null &&
                identificationResult == null &&
                !identifyingDevice)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: _InfoMessage(
                  icon: Icons.info_outline,
                  message: 'Unit belum ditemukan. Periksa IMEI dan coba lagi.',
                ),
              ),
            const SizedBox(height: 18),
            const _InfoMessage(
              icon: Icons.shield_outlined,
              message:
                  'IMEI 1 dan IMEI 2 adalah identitas dari unit yang sama. Unit duplikat akan ditolak.',
            ),
          ],
        );
      },
    );
  }

  void _setMode(_ScanMode next) {
    setState(() {
      identificationRequestId++;
      mode = next;
      foundUnit = null;
      cameraScannedImei = null;
      identificationImei = null;
      identificationResult = null;
      identifyingDevice = false;
      imeiController.clear();
    });
  }

  Future<void> _openCameraScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const ImeiCameraScannerScreen(),
      ),
    );
    if (!mounted || scanned == null) return;

    final result = parseImeiBarcode(scanned);
    if (!result.isValid) {
      _showMessage(result.error!.message);
      return;
    }

    final imei = result.value!;
    setState(() {
      identificationRequestId++;
      if (mode != _ScanMode.incoming) mode = _ScanMode.lookup;
      cameraScannedImei = imei;
      imeiController.text = imei;
      foundUnit = widget.store.unitByImei(imei);
      identificationImei = null;
      identificationResult = null;
    });
    if (widget.store.unitByImei(imei) == null) {
      await _identifyDevice(imei);
    }
  }

  Future<void> _registerUnknownImei() async {
    if (identificationResult?.status == DeviceIdentificationStatus.knownUnit) {
      _showMessage('IMEI ini sudah terdaftar sebagai unit JakStore.');
      return;
    }
    if (widget.store.variants.isEmpty) {
      _showMessage(
        'Tambahkan katalog model dan varian sebelum mencatat stok.',
      );
      return;
    }
    final parsed = parseImeiBarcode(imeiController.text);
    if (!parsed.isValid) {
      _showMessage(parsed.error!.message);
      return;
    }

    setState(() => registeringScannedImei = true);
    try {
      final model = _matchedCatalogModel(identificationResult);
      final device = identificationResult?.device;
      final saved = await widget.onRegisterUnknownImei(
        parsed.value!,
        initialModelId: model?.id,
        identifiedModelId: model?.id,
        identifiedModelName:
            device == null ? null : '${device.brand} ${device.modelName}',
      );
      if (saved == true && mounted) {
        setState(() {
          imeiController.clear();
          cameraScannedImei = null;
          foundUnit = null;
          identificationImei = null;
          identificationResult = null;
        });
        _showMessage('Unit baru berhasil ditambahkan.');
      }
    } finally {
      if (mounted) setState(() => registeringScannedImei = false);
    }
  }

  void _lookup() {
    final imei = imeiController.text.trim();
    final unit = widget.store.unitByImei(imei);
    setState(() => foundUnit = unit);
    if (unit == null && isValidImei(imei)) {
      _identifyDevice(imei);
    }
  }

  void _onImeiChanged(String value) {
    final imei = value.trim();
    setState(() {
      foundUnit = widget.store.unitByImei(imei);
      if (imei != identificationImei) {
        identificationRequestId++;
        identifyingDevice = false;
        identificationImei = null;
        identificationResult = null;
      }
    });
  }

  Future<void> _identifyDevice(String imei) async {
    if (!isValidImei(imei)) return;
    final requestId = ++identificationRequestId;
    setState(() {
      identifyingDevice = true;
      identificationImei = imei;
      identificationResult = null;
    });
    try {
      final result = await widget.deviceIdentificationService.identify(imei);
      if (!mounted ||
          requestId != identificationRequestId ||
          imeiController.text.trim() != imei) {
        return;
      }
      setState(() => identificationResult = result);
    } on Exception {
      if (!mounted ||
          requestId != identificationRequestId ||
          imeiController.text.trim() != imei) {
        return;
      }
      setState(() {
        identificationResult = DeviceIdentificationResult.unavailable(
          'Layanan identifikasi tidak dapat dihubungi. IMEI tetap tersimpan; '
          'coba lagi atau lanjutkan dengan pemilihan model manual.',
        );
      });
    } finally {
      if (mounted &&
          requestId == identificationRequestId &&
          imeiController.text.trim() == imei) {
        setState(() => identifyingDevice = false);
      }
    }
  }

  ProductModel? _matchedCatalogModel(DeviceIdentificationResult? result) {
    final device = result?.device;
    if (result?.status != DeviceIdentificationStatus.identified ||
        device == null) {
      return null;
    }
    return widget.store.modelByIdentity(
      brand: device.brand,
      modelName: device.modelName,
    );
  }

  Future<void> _submit() async {
    final imei = imeiController.text.trim();
    if (mode == _ScanMode.lookup || mode == _ScanMode.incoming) {
      if (!isValidImei(imei)) {
        _showMessage('IMEI tidak valid. Pastikan berisi 15 digit yang benar.');
        return;
      }
      final unit = widget.store.unitByImei(imei);
      setState(() => foundUnit = unit);
      if (unit == null && imei.isNotEmpty && mounted) {
        _identifyDevice(imei);
      }
      return;
    }
    if (!isValidImei(imei)) {
      _showMessage('IMEI tidak valid. Pastikan berisi 15 digit yang benar.');
      return;
    }
    final error = await widget.store.scanOutgoingOnline(
      imei,
      note: noteController.text.trim(),
    );
    if (error != null) {
      _showMessage(error);
      return;
    }
    final warning = widget.store.takeSyncWarning();
    imeiController.clear();
    noteController.clear();
    setState(() => foundUnit = null);
    _showMessage(
      warning ?? 'Barang keluar berhasil dicatat.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DeviceIdentificationProgress extends StatelessWidget {
  const _DeviceIdentificationProgress({required this.imei});

  final String imei;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IMEI terdeteksi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(imei, style: const TextStyle(letterSpacing: 0.5)),
                  const Text(
                    'Sedang mengidentifikasi perangkat...',
                    style: TextStyle(
                      color: Color(0xFF778196),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DeviceIdentificationCard extends StatelessWidget {
  const _DeviceIdentificationCard({
    required this.imei,
    required this.result,
    required this.catalogModel,
    required this.onContinue,
    required this.onRetry,
  });

  final String imei;
  final DeviceIdentificationResult result;
  final ProductModel? catalogModel;
  final VoidCallback? onContinue;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final device = result.device;
    final alreadyRegistered =
        result.status == DeviceIdentificationStatus.knownUnit;
    final identified = result.status == DeviceIdentificationStatus.identified;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: identified || alreadyRegistered
              ? const Color(0xFFD4EBDD)
              : const Color(0xFFFFE0D1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                identified || alreadyRegistered
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: identified || alreadyRegistered
                    ? const Color(0xFF16845B)
                    : const Color(0xFFC84C18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alreadyRegistered
                      ? 'IMEI sudah terdaftar'
                      : identified
                          ? 'Informasi perangkat ditemukan'
                          : 'Model belum teridentifikasi',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'IMEI terdeteksi',
            style: TextStyle(color: Color(0xFF778196), fontSize: 11),
          ),
          Text(imei, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            result.message,
            style: const TextStyle(
              color: Color(0xFF657084),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (device != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Informasi perangkat',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            _DeviceDetailRow(label: 'Merek', value: device.brand),
            _DeviceDetailRow(label: 'Model', value: device.modelName),
            if (device.modelCode?.isNotEmpty ?? false)
              _DeviceDetailRow(label: 'Kode model', value: device.modelCode!),
            if (device.tac?.isNotEmpty ?? false)
              _DeviceDetailRow(label: 'TAC', value: device.tac!),
            _DeviceDetailRow(label: 'Sumber', value: device.source),
            const SizedBox(height: 7),
            if (alreadyRegistered)
              const Text(
                'Unit ini sudah tercatat di inventori dan tidak dapat '
                'didaftarkan ulang.',
                style: TextStyle(
                  color: Color(0xFF176B4C),
                  fontSize: 11,
                  height: 1.4,
                ),
              )
            else if (catalogModel != null)
              Text(
                'Cocok dengan katalog JakStore: ${catalogModel!.displayName}. '
                'Warna dan kapasitas tetap harus dipilih sesuai unit fisik.',
                style: const TextStyle(
                  color: Color(0xFF176B4C),
                  fontSize: 11,
                  height: 1.4,
                ),
              )
            else
              const Text(
                'Model ini belum cocok persis dengan katalog JakStore. '
                'Pilih model secara manual; model baru tidak dibuat otomatis.',
                style: TextStyle(
                  color: Color(0xFFC84C18),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
          ],
          if (alreadyRegistered && result.knownUnitStatus != null)
            _DeviceDetailRow(
              label: 'Status unit',
              value: result.knownUnitStatus!,
            ),
          const SizedBox(height: 7),
          const Text(
            'Informasi model bukan verifikasi keaslian, status legal, atau '
            'blacklist perangkat.',
            style: TextStyle(
              color: Color(0xFF778196),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba identifikasi lagi'),
            ),
          ],
          if (alreadyRegistered) ...[
            const SizedBox(height: 8),
            Text(
              result.knownUnitId == null
                  ? 'Unit ini tidak dapat didaftarkan ulang.'
                  : 'ID unit: ${result.knownUnitId}. Unit ini tidak dapat '
                      'didaftarkan ulang.',
              style: const TextStyle(
                color: Color(0xFFC84C18),
                fontSize: 11,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Simpan'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16845B),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceDetailRow extends StatelessWidget {
  const _DeviceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF778196),
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF10172A)
                    : const Color(0xFF778196),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
}

class _UnitLookupCard extends StatelessWidget {
  const _UnitLookupCard({
    required this.unit,
    required this.variant,
    required this.displayName,
    required this.matchedImei,
    required this.onOpenUnit,
  });

  final PhoneUnit unit;
  final ProductVariant variant;
  final String displayName;
  final String matchedImei;
  final VoidCallback onOpenUnit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unit ditemukan',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF16845B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${variant.color} • ${variant.storage}',
              style: const TextStyle(color: Color(0xFF778196), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text('IMEI 1: ${unit.imei1}'),
            if (unit.imei2 != null) Text('IMEI 2: ${unit.imei2}'),
            if (unit.imei2 == matchedImei)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  'Barcode cocok dengan IMEI 2 dari unit yang sama.',
                  style: TextStyle(
                    color: Color(0xFF778196),
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 9),
            StatusBadge(status: unit.status),
            const SizedBox(height: 8),
            Text(
              'Dicatat ${_formatDate(unit.recordedAt)}',
              style: const TextStyle(color: Color(0xFF778196), fontSize: 11),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenUnit,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka detail unit'),
            ),
          ],
        ),
      );
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2EA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC84C18), size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF75452F),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
