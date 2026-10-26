import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../utils/imei.dart';

class ImeiCameraScannerScreen extends StatefulWidget {
  const ImeiCameraScannerScreen({super.key});

  @override
  State<ImeiCameraScannerScreen> createState() =>
      _ImeiCameraScannerScreenState();
}

class _ImeiCameraScannerScreenState extends State<ImeiCameraScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
  );

  String? candidateImei;
  String? feedback;
  String? lastRejectedValue;
  bool processing = false;
  bool disposed = false;
  bool resumeAfterLifecyclePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (resumeAfterLifecyclePause && candidateImei == null && !processing) {
        resumeAfterLifecyclePause = false;
        _startScanner();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (controller.value.isRunning) {
        resumeAfterLifecyclePause = candidateImei == null && !processing;
        unawaited(controller.stop());
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              useAppLifecycleState: false,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraErrorView(
                error: error,
                onRetry: _retry,
                onManualEntry: () => Navigator.of(context).pop(),
              ),
              placeholderBuilder: (_) => const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan barcode IMEI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      if (state.torchState == TorchState.unavailable) {
                        return const SizedBox(width: 48);
                      }
                      return IconButton.filledTonal(
                        tooltip: state.torchState == TorchState.on
                            ? 'Matikan lampu'
                            : 'Nyalakan lampu',
                        onPressed: _toggleTorch,
                        icon: Icon(
                          state.torchState == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) {
                if (state.error != null || candidateImei != null) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 310,
                      height: 118,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFF8A58),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Arahkan barcode ke dalam kotak',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: [Shadow(blurRadius: 8)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (context, state, _) {
                  if (state.error != null) return const SizedBox.shrink();
                  return _ScannerStatusPanel(
                    candidateImei: candidateImei,
                    feedback: feedback,
                    onUse: _useCandidate,
                    onRescan: _resumeScanning,
                    onManualEntry: () => Navigator.of(context).pop(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (processing || candidateImei != null) return;

    if (capture.barcodes.isEmpty) return;
    final values = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .toList(growable: false);
    if (values.isEmpty) {
      if (lastRejectedValue == '\u0000') return;
      lastRejectedValue = '\u0000';
      setState(
        () => feedback = ImeiParseError.empty.message,
      );
      return;
    }

    for (final rawValue in values) {
      final result = parseImeiBarcode(rawValue);
      if (result.value case final imei?) {
        processing = true;
        candidateImei = imei;
        feedback = null;
        setState(() {});
        unawaited(controller.pause());
        return;
      }
    }

    final rejected = values.first;
    if (rejected == lastRejectedValue) return;
    lastRejectedValue = rejected;
    final result = parseImeiBarcode(rejected);
    setState(() => feedback = result.error!.message);
  }

  Future<void> _startScanner() async {
    if (disposed || candidateImei != null || controller.value.isStarting)
      return;
    try {
      await controller.start();
    } on MobileScannerException catch (error) {
      if (!disposed && mounted) {
        setState(() => feedback = error.errorCode.message);
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      feedback = null;
      lastRejectedValue = null;
    });
    await _startScanner();
  }

  Future<void> _toggleTorch() async {
    try {
      await controller.toggleTorch();
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => feedback = error.errorCode.message);
    }
  }

  Future<void> _resumeScanning() async {
    setState(() {
      candidateImei = null;
      processing = false;
      feedback = null;
      lastRejectedValue = null;
    });
    await _startScanner();
  }

  Future<void> _useCandidate() async {
    final imei = candidateImei;
    if (imei == null || processing == false) return;
    processing = false;
    await controller.stop();
    if (mounted) Navigator.of(context).pop(imei);
  }
}

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({
    required this.error,
    required this.onRetry,
    required this.onManualEntry,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Aktifkan izin kamera untuk JakStore di Pengaturan, atau masukkan IMEI secara manual.',
      MobileScannerErrorCode.unsupported =>
        'Kamera tidak tersedia pada perangkat ini. Anda tetap dapat memasukkan IMEI secara manual.',
      _ =>
        'Kamera gagal dijalankan. Periksa izin kamera dan coba lagi, atau masukkan IMEI secara manual.',
    };

    return ColoredBox(
      color: const Color(0xFF10172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Color(0xFFFF8A58), size: 44),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
              TextButton(
                onPressed: onManualEntry,
                child: const Text('Masukkan IMEI manual'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerStatusPanel extends StatelessWidget {
  const _ScannerStatusPanel({
    required this.candidateImei,
    required this.feedback,
    required this.onUse,
    required this.onRescan,
    required this.onManualEntry,
  });

  final String? candidateImei;
  final String? feedback;
  final VoidCallback onUse;
  final VoidCallback onRescan;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final imei = candidateImei;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xF210172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imei != null) ...[
            const Text(
              'IMEI terbaca',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 5),
            SelectableText(
              imei,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRescan,
                    child: const Text('Scan ulang'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onUse,
                    child: const Text('Gunakan IMEI'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              feedback ?? 'Posisikan barcode IMEI di dalam area panduan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    feedback == null ? Colors.white : const Color(0xFFFFB59A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onManualEntry,
              child: const Text('Masukkan IMEI manual'),
            ),
          ],
        ],
      ),
    );
  }
}
