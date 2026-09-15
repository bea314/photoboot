import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:image/image.dart' as img;

/// Result of thermal rasterization ready for ESC/POS send.
class ThermalRasterResult {
  const ThermalRasterResult({
    required this.widthDots,
    required this.heightDots,
    required this.bytesPerRow,
    required this.bitmap,
    required this.escPosPayload,
  });

  final int widthDots;
  final int heightDots;
  final int bytesPerRow;

  /// Packed 1-bit rows (MSB leftmost), size = bytesPerRow * heightDots.
  final Uint8List bitmap;

  /// Full ESC/POS command stream including init + bitmap + feed/cut.
  final Uint8List escPosPayload;
}

enum ThermalDitherMode {
  /// Floyd–Steinberg error diffusion (better photo look).
  floydSteinberg,

  /// Simple threshold (high contrast / text-friendly).
  threshold,
}

/// Rasterizes a JPEG/PNG into an ESC/POS raster bit image for thermal printers.
class ThermalEscPosRasterizer {
  const ThermalEscPosRasterizer();

  /// Decode [imageBytes], center-crop to [profile], scale to thermal width,
  /// dither, and wrap as ESC/POS `GS v 0` bitmap.
  ThermalRasterResult rasterize({
    required Uint8List imageBytes,
    PrinterProfile? profile,
    int? dotsWidth,
    ThermalDitherMode dither = ThermalDitherMode.floydSteinberg,
    int threshold = 128,
    bool includeCut = true,
  }) {
    final resolved = profile ?? PrinterProfile.byId(PrinterProfileId.thermal80);
    final targetWidth = dotsWidth ?? resolved.thermalDotsWidth ?? 576;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image for thermal print');
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
      width: math.max(1, crop.width.round().clamp(1, decoded.width)),
      height: math.max(1, crop.height.round().clamp(1, decoded.height)),
    );

    final scale = targetWidth / cropped.width;
    final targetHeight = math.max(1, (cropped.height * scale).round());
    final resized = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    final gray = img.grayscale(resized);
    final mono = dither == ThermalDitherMode.floydSteinberg
        ? _floydSteinberg(gray)
        : _threshold(gray, threshold);

    final bytesPerRow = (targetWidth + 7) ~/ 8;
    final bitmap = _packBitmap(mono, targetWidth, targetHeight, bytesPerRow);
    final payload = buildEscPosRaster(
      widthDots: targetWidth,
      heightDots: targetHeight,
      bitmap: bitmap,
      includeCut: includeCut,
    );

    return ThermalRasterResult(
      widthDots: targetWidth,
      heightDots: targetHeight,
      bytesPerRow: bytesPerRow,
      bitmap: bitmap,
      escPosPayload: payload,
    );
  }

  /// Builds ESC/POS init + GS v 0 raster + feed (+ optional partial cut).
  static Uint8List buildEscPosRaster({
    required int widthDots,
    required int heightDots,
    required Uint8List bitmap,
    bool includeCut = true,
  }) {
    final bytesPerRow = (widthDots + 7) ~/ 8;
    final expected = bytesPerRow * heightDots;
    if (bitmap.length < expected) {
      throw ArgumentError('Bitmap too short: ${bitmap.length} < $expected');
    }

    final out = BytesBuilder(copy: false);
    // ESC @ — initialize
    out.add([0x1B, 0x40]);
    // GS v 0 m xL xH yL yH d1…dk  (m=0 normal)
    final xL = bytesPerRow & 0xff;
    final xH = (bytesPerRow >> 8) & 0xff;
    final yL = heightDots & 0xff;
    final yH = (heightDots >> 8) & 0xff;
    out.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
    out.add(bitmap.sublist(0, expected));
    // Feed a few lines
    out.add([0x1B, 0x64, 0x04]);
    if (includeCut) {
      // GS V 0 — full cut
      out.add([0x1D, 0x56, 0x00]);
    }
    return out.toBytes();
  }

  /// Text lines as ESC/POS for test tickets (simple ASCII).
  static Uint8List buildTextLines(List<String> lines, {bool bold = false}) {
    final out = BytesBuilder(copy: false);
    out.add([0x1B, 0x40]); // init
    if (bold) out.add([0x1B, 0x45, 0x01]); // bold on
    for (final line in lines) {
      out.add(Uint8List.fromList(line.codeUnits));
      out.add([0x0A]);
    }
    if (bold) out.add([0x1B, 0x45, 0x00]);
    return out.toBytes();
  }

  static img.Image _threshold(img.Image gray, int threshold) {
    final out = img.Image(width: gray.width, height: gray.height);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final p = gray.getPixel(x, y);
        final v = p.r.toInt();
        final bit = v < threshold ? 0 : 255;
        out.setPixelRgb(x, y, bit, bit, bit);
      }
    }
    return out;
  }

  static img.Image _floydSteinberg(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final buffer = List<double>.generate(w * h, (i) {
      final x = i % w;
      final y = i ~/ w;
      return gray.getPixel(x, y).r.toDouble();
    });

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        final old = buffer[idx];
        final neu = old < 128 ? 0.0 : 255.0;
        buffer[idx] = neu;
        final err = old - neu;
        if (x + 1 < w) buffer[idx + 1] += err * 7 / 16;
        if (y + 1 < h) {
          if (x > 0) buffer[idx + w - 1] += err * 3 / 16;
          buffer[idx + w] += err * 5 / 16;
          if (x + 1 < w) buffer[idx + w + 1] += err * 1 / 16;
        }
      }
    }

    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = buffer[y * w + x] < 128 ? 0 : 255;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  static Uint8List _packBitmap(
    img.Image mono,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final data = Uint8List(bytesPerRow * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final lum = mono.getPixel(x, y).r.toInt();
        // ESC/POS: 1 = black dot
        if (lum < 128) {
          final byteIndex = y * bytesPerRow + (x >> 3);
          data[byteIndex] |= 0x80 >> (x & 7);
        }
      }
    }
    return data;
  }
}
