import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';
import 'package:image/image.dart' as img;

/// Generated 10×15 layout ready for an Epson send path.
class EpsonPrintLayout {
  const EpsonPrintLayout({
    required this.widthPx,
    required this.heightPx,
    required this.jpegBytes,
    required this.dpi,
  });

  final int widthPx;
  final int heightPx;
  final Uint8List jpegBytes;
  final int dpi;
}

/// Scaffold for Epson L8050 10×15 printing (Phase D5).
///
/// Generates a center-cropped JPEG at ≥300 ppp. Full SDK / system print
/// queue wiring is intentionally left as TODO — booth hardware verification
/// happens later.
class EpsonPrintScaffold {
  const EpsonPrintScaffold();

  /// 10 cm × 15 cm at [dpi] (default 300) → 1181 × 1772 px.
  EpsonPrintLayout buildPrintLayout({
    required Uint8List imageBytes,
    PrinterProfile? profile,
    int dpi = 300,
  }) {
    final resolved =
        profile ?? PrinterProfile.byId(PrinterProfileId.epsonL80504x6);
    final targetDpi = resolved.targetDpi ?? dpi;

    // Physical size 10×15 cm.
    final widthPx = (10 / 2.54 * targetDpi).round();
    final heightPx = (15 / 2.54 * targetDpi).round();

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image for Epson layout');
    }

    final crop = centerCropRect(
      sourceWidth: decoded.width.toDouble(),
      sourceHeight: decoded.height.toDouble(),
      aspectRatio: resolved.aspectRatio,
    );

    final cropped = img.copyCrop(
      decoded,
      x: crop.left.round().clamp(0, decoded.width - 1),
      y: crop.top.round().clamp(0, decoded.height - 1),
      width: math.max(1, crop.width.round()),
      height: math.max(1, crop.height.round()),
    );

    final resized = img.copyResize(
      cropped,
      width: widthPx,
      height: heightPx,
      interpolation: img.Interpolation.cubic,
    );

    final jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 92));
    return EpsonPrintLayout(
      widthPx: widthPx,
      heightPx: heightPx,
      jpegBytes: jpeg,
      dpi: targetDpi,
    );
  }

  /// Preferred: Epson SDK / silent system queue. Fallback: OS print dialog.
  Future<void> sendToPrinter({
    required EpsonPrintLayout layout,
    PrinterTransport? transport,
  }) async {
    // TODO(D5): Integrate Epson ePOS / WiFi Direct / platform print channel.
    // TODO(D5): Fallback to native print dialog (AirPrint / Mopria).
    //
    // For now we refuse silent send so thermal remains the primary path and
    // callers see a clear message instead of a false "printed".
    throw PrinterException(
      PrinterErrorCode.unsupported,
      'Epson L8050 send path not wired yet '
      '(layout ready: ${layout.widthPx}×${layout.heightPx} @ ${layout.dpi}dpi, '
      '${layout.jpegBytes.length} bytes JPEG). '
      'Use thermal_80 for booth printing until D5 hardware lands.',
    );
  }
}
