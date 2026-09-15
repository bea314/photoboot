import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/printing/print_crop.dart' as crop;
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

/// Shows how a photo will be center-cropped for the active printer profile.
class PrintPreviewFrame extends StatelessWidget {
  const PrintPreviewFrame({
    super.key,
    required this.profile,
    this.image,
    this.imageBytes,
    this.height = 280,
  });

  final PrinterProfile profile;
  final ImageProvider? image;
  final Uint8List? imageBytes;
  final double height;

  ImageProvider? get _provider {
    if (imageBytes != null) return MemoryImage(imageBytes!);
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          profile.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recorte ${profile.frameLabel}',
          style: const TextStyle(color: AppColors.grey),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: Center(
            child: AspectRatio(
              aspectRatio: profile.aspectRatio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.red, width: 3),
                ),
                child: ClipRect(
                  child: provider == null
                      ? const _PreviewFallback()
                      : Image(
                          image: provider,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const _PreviewFallback(),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Side-by-side thermal vs Epson crop comparison for the same photo.
class DualPrintPreview extends StatelessWidget {
  const DualPrintPreview({
    super.key,
    this.imageBytes,
    this.image,
  });

  final Uint8List? imageBytes;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PrintPreviewFrame(
            profile: PrinterProfile.byId(PrinterProfileId.thermal80),
            imageBytes: imageBytes,
            image: image,
            height: 220,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrintPreviewFrame(
            profile: PrinterProfile.byId(PrinterProfileId.epsonL80504x6),
            imageBytes: imageBytes,
            image: image,
            height: 220,
          ),
        ),
      ],
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: CustomPaint(
        painter: _ContrastBlockPainter(),
        child: const Center(
          child: Text(
            'SAMPLE',
            style: TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContrastBlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const cols = 8;
    const rows = 8;
    final w = size.width / cols;
    final h = size.height / rows;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        paint.color = ((x + y) % 2 == 0) ? AppColors.red : AppColors.white;
        canvas.drawRect(Rect.fromLTWH(x * w, y * h, w, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Builds a sample ui.Image for demos (checker + brand text).
Future<ui.Image> createSampleUiImage({int width = 600, int height = 800}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();
  const cols = 6;
  const rows = 8;
  final cellW = width / cols;
  final cellH = height / rows;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      paint.color = ((x + y) % 2 == 0)
          ? const Color(0xFFE10600)
          : const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH), paint);
    }
  }
  final textPainter = TextPainter(
    text: const TextSpan(
      text: 'FOTOBOOT',
      style: TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 48,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    Offset((width - textPainter.width) / 2, (height - textPainter.height) / 2),
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

crop.CropRect cropForProfile(Size source, PrinterProfile profile) {
  return crop.centerCropRect(
    sourceWidth: source.width,
    sourceHeight: source.height,
    aspectRatio: profile.aspectRatio,
  );
}
