import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/qr/pairing_payload.dart';

/// QR scanner page for pairing / adding a contact.
///
/// Scans QR codes generated from [PairingPayloadBuilder] (JSON payload).
///
/// What this page does:
/// - Opens camera and scans a QR code
/// - Validates and parses JSON into [PairingPayload]
/// - Returns the parsed payload via `Navigator.pop(context, payload)`
///
/// What this page does NOT do (yet):
/// - Persist contacts
/// - Connect to the peer
/// - Verify signatures / safety numbers
///
/// Usage:
/// ```dart
/// final payload = await Navigator.of(context).push<PairingPayload>(
///   MaterialPageRoute(builder: (_) => const ScanQrPage()),
/// );
/// if (payload != null) { ... }
/// ```
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController(
    // Default to back camera; user can flip.
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _handling = false;
  String? _error;
  String? _lastRaw;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handling) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Try to find a meaningful string payload.
    final raw = barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );

    if (raw.isEmpty) return;
    if (raw == _lastRaw) return; // reduce repeated attempts on same frame

    setState(() {
      _handling = true;
      _error = null;
      _lastRaw = raw;
    });

    try {
      final payload = _parsePayload(raw);
      if (!mounted) return;

      // Stop camera before leaving.
      await _controller.stop();

      if (!mounted) return;
      Navigator.of(context).pop(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _handling = false;
      });

      // Keep scanning after a short delay to avoid immediate spam.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _handling = false);
    }
  }

  PairingPayload _parsePayload(String raw) {
    // Expect JSON object, produced by PairingPayload.toJsonString.
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('QR payload: expected a JSON object');
    }

    final payload = PairingPayload.fromJson(
      decoded.map((k, v) => MapEntry(k.toString(), v)),
    );

    // Minimal validation.
    if (payload.peerId.trim().isEmpty) {
      throw const FormatException('QR payload: missing peerId');
    }
    if (payload.v <= 0) {
      throw const FormatException('QR payload: invalid version');
    }

    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR'),
        actions: [
          IconButton(
            tooltip: 'Переключить камеру',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
          ValueListenableBuilder<TorchState>(
            valueListenable: _controller.torchState,
            builder: (context, state, _) {
              final isOn = state == TorchState.on;
              return IconButton(
                tooltip: isOn ? 'Выключить фонарик' : 'Включить фонарик',
                onPressed: () => _controller.toggleTorch(),
                icon: Icon(isOn ? Icons.flash_on : Icons.flash_off),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error, child) {
              return _CameraError(
                message: error.errorCode.name,
                details: error.toString(),
              );
            },
          ),
          // Overlay: scan frame and helper text
          IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                color: cs.primary,
                borderRadius: 16,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Bottom helper sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _BottomPanel(
                  busy: _handling,
                  error: _error,
                  lastRawPreview: _lastRaw,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final bool busy;
  final String? error;
  final String? lastRawPreview;

  const _BottomPanel({
    required this.busy,
    required this.error,
    required this.lastRawPreview,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: cs.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Наведи камеру на QR для сопряжения',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: cs.error,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (lastRawPreview != null && lastRawPreview!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Последнее содержимое'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        lastRawPreview!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final String message;
  final String details;

  const _CameraError({
    required this.message,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Камера недоступна',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(color: cs.error),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    details,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Проверь разрешение CAMERA в настройках приложения.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  const _ScannerOverlayPainter({
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Frame size relative to screen.
    final shortest = size.shortestSide;
    final frameSize = shortest * 0.72;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;

    final rect = Rect.fromLTWH(left, top, frameSize, frameSize);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Dim outside area.
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);

    // Border.
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(rrect, borderPaint);

    // Corner accents.
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 26.0;
    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;

    // top-left
    canvas.drawLine(tl, tl + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(tl, tl + const Offset(0, cornerLen), cornerPaint);

    // top-right
    canvas.drawLine(tr, tr + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(tr, tr + const Offset(0, cornerLen), cornerPaint);

    // bottom-left
    canvas.drawLine(bl, bl + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(bl, bl + const Offset(0, -cornerLen), cornerPaint);

    // bottom-right
    canvas.drawLine(br, br + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(br, br + const Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderRadius != borderRadius;
  }
}
