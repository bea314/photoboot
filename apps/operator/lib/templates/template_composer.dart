import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shared preview/print renderer: paints [PrintTemplate] layers onto a canvas.
///
/// Photo slots use center-crop **cover** into the slot rect (same math as
/// [centerCropNormalized] / thermal path).
class TemplateLayoutPainter extends CustomPainter {
  TemplateLayoutPainter({
    required this.template,
    required this.context,
    this.photos = const [],
    this.showPaperBorder = true,
  });

  final PrintTemplate template;
  final TemplatePrintContext context;
  final List<ui.Image?> photos;
  final bool showPaperBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = _fitPaper(size, template.paper.aspectRatio);
    canvas.drawRect(paper, Paint()..color = Colors.white);
    if (showPaperBorder) {
      canvas.drawRect(
        paper,
        Paint()
          ..color = AppColors.red.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    var slotIndex = 0;
    for (final layer in template.layers) {
      final rect = Rect.fromLTWH(
        paper.left + layer.x * paper.width,
        paper.top + layer.y * paper.height,
        layer.w * paper.width,
        layer.h * paper.height,
      );
      switch (layer.type) {
        case TemplateLayerType.photoSlot:
          final photo =
              slotIndex < photos.length ? photos[slotIndex] : null;
          slotIndex++;
          _paintPhotoSlot(canvas, rect, photo);
        case TemplateLayerType.image:
          _paintLogo(canvas, rect);
        case TemplateLayerType.text:
          _paintText(canvas, rect, context.resolve(layer.text));
        case TemplateLayerType.qr:
          _paintQr(canvas, rect, context.qrPayload);
      }
    }
  }

  void _paintPhotoSlot(Canvas canvas, Rect slot, ui.Image? photo) {
    canvas.save();
    canvas.clipRect(slot);
    if (photo == null) {
      canvas.drawRect(
        slot,
        Paint()..color = AppColors.red.withValues(alpha: 0.08),
      );
      final stroke = Paint()
        ..color = AppColors.red.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRect(slot, stroke);
    } else {
      final srcAspect = photo.width / photo.height;
      final dstAspect = slot.width / slot.height;
      final crop = centerCropNormalized(
        sourceAspect: srcAspect,
        targetAspect: dstAspect,
      );
      final src = Rect.fromLTWH(
        crop.left * photo.width,
        crop.top * photo.height,
        crop.width * photo.width,
        crop.height * photo.height,
      );
      canvas.drawImageRect(photo, src, slot, Paint());
    }
    canvas.restore();
  }

  void _paintLogo(Canvas canvas, Rect rect) {
    final fill = Paint()..color = AppColors.red;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(r, fill);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'FB',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: rect.width);
    tp.paint(
      canvas,
      Offset(
        rect.center.dx - tp.width / 2,
        rect.center.dy - tp.height / 2,
      ),
    );
  }

  void _paintText(Canvas canvas, Rect rect, String text) {
    if (text.isEmpty) return;
    final fontSize = (rect.height * 0.55).clamp(10.0, 36.0);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);
    tp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      ),
    );
  }

  void _paintQr(Canvas canvas, Rect rect, String? payload) {
    final data = (payload == null || payload.isEmpty)
        ? 'https://fotoboot.app'
        : payload;
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: AppColors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: AppColors.black,
      ),
    );
    canvas.save();
    canvas.translate(rect.left, rect.top);
    painter.paint(canvas, rect.size);
    canvas.restore();
  }

  Rect _fitPaper(Size size, double aspect) {
    late Size paper;
    if (size.width / size.height > aspect) {
      paper = Size(size.height * aspect, size.height);
    } else {
      paper = Size(size.width, size.width / aspect);
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: paper.width,
      height: paper.height,
    );
  }

  @override
  bool shouldRepaint(covariant TemplateLayoutPainter oldDelegate) {
    return oldDelegate.template.id != template.id ||
        oldDelegate.context.evento != context.evento ||
        oldDelegate.context.fecha != context.fecha ||
        oldDelegate.context.hora != context.hora ||
        oldDelegate.context.eventUrl != context.eventUrl ||
        oldDelegate.photos != photos;
  }
}

/// Composes one template page to PNG bytes (same painter as preview).
class TemplateComposer {
  const TemplateComposer();

  /// Renders [template] at [widthPx] (height from paper aspect).
  Future<Uint8List> composePng({
    required PrintTemplate template,
    required TemplatePrintContext context,
    List<Uint8List> photoBytes = const [],
    int widthPx = 576,
    bool showPaperBorder = false,
  }) async {
    final heightPx =
        (widthPx / template.paper.aspectRatio).round().clamp(1, 4096);
    final decoded = <ui.Image?>[];
    for (final bytes in photoBytes) {
      decoded.add(await _decode(bytes));
    }
    // Pad missing slots with nulls so empty slots still paint.
    while (decoded.length < template.slotCount) {
      decoded.add(null);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(widthPx.toDouble(), heightPx.toDouble());
    TemplateLayoutPainter(
      template: template,
      context: context,
      photos: decoded,
      showPaperBorder: showPaperBorder,
    ).paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(widthPx, heightPx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    for (final p in decoded) {
      p?.dispose();
    }
    if (byteData == null) {
      throw StateError('Failed to encode template page');
    }
    return byteData.buffer.asUint8List();
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// On-screen preview using the same [TemplateLayoutPainter].
class TemplatePrintPreview extends StatelessWidget {
  const TemplatePrintPreview({
    super.key,
    required this.template,
    required this.contextData,
    this.photos = const [],
    this.height = 240,
  });

  final PrintTemplate template;
  final TemplatePrintContext contextData;
  final List<ui.Image?> photos;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: AspectRatio(
          aspectRatio: template.paper.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: CustomPaint(
              painter: TemplateLayoutPainter(
                template: template,
                context: contextData,
                photos: photos,
                showPaperBorder: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
