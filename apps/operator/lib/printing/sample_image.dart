import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Builds a branded contrast sample PNG for test prints / demos.
Uint8List buildSamplePng({int width = 480, int height = 640}) {
  final image = img.Image(width: width, height: height);
  const cols = 6;
  const rows = 8;
  final cellW = width / cols;
  final cellH = height / rows;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final on = (x + y) % 2 == 0;
      final color = on
          ? img.ColorRgb8(0xE1, 0x06, 0x00)
          : img.ColorRgb8(0xFF, 0xFF, 0xFF);
      img.fillRect(
        image,
        x1: (x * cellW).round(),
        y1: (y * cellH).round(),
        x2: ((x + 1) * cellW).round() - 1,
        y2: ((y + 1) * cellH).round() - 1,
        color: color,
      );
    }
  }
  // Brand bar without relying on bundled bitmap fonts.
  img.fillRect(
    image,
    x1: width ~/ 6,
    y1: height ~/ 2 - 20,
    x2: width - width ~/ 6,
    y2: height ~/ 2 + 20,
    color: img.ColorRgb8(0x1A, 0x1A, 0x1A),
  );
  img.fillRect(
    image,
    x1: width ~/ 6 + 4,
    y1: height ~/ 2 - 16,
    x2: width - width ~/ 6 - 4,
    y2: height ~/ 2 + 16,
    color: img.ColorRgb8(0xFF, 0xFF, 0xFF),
  );
  return Uint8List.fromList(img.encodePng(image));
}

/// Builds a high-contrast greyscale block strip for thermal test tickets.
Uint8List buildContrastBlockPng({int width = 384, int height = 64}) {
  final image = img.Image(width: width, height: height);
  for (var x = 0; x < width; x++) {
    final t = (x / (width - 1) * 255).round();
    for (var y = 0; y < height; y++) {
      image.setPixelRgb(x, y, t, t, t);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
