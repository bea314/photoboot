import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

Color? _parseHex(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// Shared preview/print renderer: paints [PrintTemplate] layers onto a canvas.
///
/// Photo slots use center-crop **cover** by default (same math as
/// [centerCropNormalized] / thermal path). Also supports contain/fill.
class TemplateLayoutPainter extends CustomPainter {
  TemplateLayoutPainter({
    required this.template,
    required this.context,
    this.photos = const [],
    this.assets = const {},
    this.showPaperBorder = true,
    this.showSlotLabels = false,
    this.selectedLayerId,
  });

  final PrintTemplate template;
  final TemplatePrintContext context;
  final List<ui.Image?> photos;
  final Map<String, ui.Image?> assets;
  final bool showPaperBorder;
  final bool showSlotLabels;
  final String? selectedLayerId;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = fitPaperRect(size, template.paper.aspectRatio);
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

    final slotOrder = {
      for (var i = 0; i < template.orderedPhotoSlots.length; i++)
        template.orderedPhotoSlots[i].id: i,
    };

    for (final layer in template.layers) {
      if (!layer.visible) continue;
      final rect = layerRect(paper, layer);
      canvas.saveLayer(
        rect.inflate(2),
        Paint()..color = Colors.white.withValues(alpha: layer.opacity),
      );
      switch (layer.type) {
        case TemplateLayerType.background:
          _paintBackground(canvas, rect, layer);
        case TemplateLayerType.photoSlot:
          final idx = slotOrder[layer.id] ?? 0;
          final photo = idx < photos.length ? photos[idx] : null;
          _paintPhotoSlot(canvas, rect, photo, layer);
          if (showSlotLabels) {
            _paintSlotLabel(canvas, rect, layer.slotIndex ?? (idx + 1));
          }
        case TemplateLayerType.image:
          _paintImage(canvas, rect, layer);
        case TemplateLayerType.text:
          _paintText(canvas, rect, context.resolve(layer.text));
        case TemplateLayerType.qr:
          _paintQr(canvas, rect, _qrPayload(layer));
        case TemplateLayerType.shape:
          _paintShape(canvas, rect, layer);
      }
      canvas.restore();

      if (selectedLayerId == layer.id) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = AppColors.red
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  String? _qrPayload(TemplateLayer layer) {
    if (layer.valueKey == 'eventUrl') return context.qrPayload;
    final resolved = context.resolve(layer.text);
    if (resolved.isNotEmpty) return resolved;
    return context.qrPayload;
  }

  void _paintBackground(Canvas canvas, Rect rect, TemplateLayer layer) {
    final fill = _parseHex(layer.fillColor);
    if (fill != null) {
      canvas.drawRect(rect, Paint()..color = fill);
    }
    final key = layer.assetKey;
    final image = key == null ? null : assets[key];
    if (image != null) {
      _drawFittedImage(canvas, rect, image, layer.fit ?? 'contain');
    }
  }

  void _paintPhotoSlot(
    Canvas canvas,
    Rect slot,
    ui.Image? photo,
    TemplateLayer layer,
  ) {
    final radius = (layer.cornerRadius ?? 0) * slot.shortestSide;
    canvas.save();
    if (radius > 0) {
      canvas.clipRRect(
        RRect.fromRectAndRadius(slot, Radius.circular(radius)),
      );
    } else {
      canvas.clipRect(slot);
    }
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
      _drawFittedImage(canvas, slot, photo, layer.fit ?? 'cover');
    }
    canvas.restore();
  }

  void _paintSlotLabel(Canvas canvas, Rect rect, int index) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Foto $index',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 6,
        rect.top + 6,
        tp.width + pad.horizontal,
        tp.height + pad.vertical,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = AppColors.black.withValues(alpha: 0.55),
    );
    tp.paint(canvas, Offset(rect.left + 6 + pad.left, rect.top + 6 + pad.top));
  }

  void _paintImage(Canvas canvas, Rect rect, TemplateLayer layer) {
    final key = layer.assetKey;
    final image = key == null ? null : assets[key];
    if (image != null) {
      final radius = (layer.cornerRadius ?? 0) * rect.shortestSide;
      canvas.save();
      if (radius > 0) {
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        );
      }
      _drawFittedImage(canvas, rect, image, layer.fit ?? 'contain');
      canvas.restore();
      return;
    }
    // Placeholder logo mark (legacy seeds without asset).
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

  void _paintShape(Canvas canvas, Rect rect, TemplateLayer layer) {
    final fill = _parseHex(layer.fillColor) ?? AppColors.red;
    final stroke = _parseHex(layer.strokeColor);
    final paint = Paint()..color = fill;
    if (layer.shapeKind == 'circle') {
      canvas.drawOval(rect, paint);
      if (stroke != null) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    } else {
      final radius = (layer.cornerRadius ?? 0) * rect.shortestSide;
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, paint);
      if (stroke != null) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
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

  void _drawFittedImage(
    Canvas canvas,
    Rect dst,
    ui.Image image,
    String fit,
  ) {
    final srcAspect = image.width / image.height;
    final dstAspect = dst.width / dst.height;
    if (fit == 'fill') {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        Paint(),
      );
      return;
    }
    if (fit == 'contain') {
      late Rect fitted;
      if (srcAspect > dstAspect) {
        final h = dst.width / srcAspect;
        fitted = Rect.fromCenter(
          center: dst.center,
          width: dst.width,
          height: h,
        );
      } else {
        final w = dst.height * srcAspect;
        fitted = Rect.fromCenter(
          center: dst.center,
          width: w,
          height: dst.height,
        );
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        fitted,
        Paint(),
      );
      return;
    }
    // cover (default)
    final crop = centerCropNormalized(
      sourceAspect: srcAspect,
      targetAspect: dstAspect,
    );
    final src = Rect.fromLTWH(
      crop.left * image.width,
      crop.top * image.height,
      crop.width * image.width,
      crop.height * image.height,
    );
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant TemplateLayoutPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.context.evento != context.evento ||
        oldDelegate.context.fecha != context.fecha ||
        oldDelegate.context.hora != context.hora ||
        oldDelegate.context.eventUrl != context.eventUrl ||
        oldDelegate.photos != photos ||
        oldDelegate.assets != assets ||
        oldDelegate.selectedLayerId != selectedLayerId ||
        oldDelegate.showSlotLabels != showSlotLabels;
  }
}

Rect fitPaperRect(Size size, double aspect) {
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

Rect layerRect(Rect paper, TemplateLayer layer) {
  return Rect.fromLTWH(
    paper.left + layer.x * paper.width,
    paper.top + layer.y * paper.height,
    layer.w * paper.width,
    layer.h * paper.height,
  );
}

/// Composes one template page to PNG bytes (same painter as preview).
class TemplateComposer {
  const TemplateComposer();

  /// Renders [template] at [widthPx] (height from paper aspect).
  Future<Uint8List> composePng({
    required PrintTemplate template,
    required TemplatePrintContext context,
    List<Uint8List> photoBytes = const [],
    Map<String, Uint8List> assetBytes = const {},
    int widthPx = 576,
    bool showPaperBorder = false,
  }) async {
    final heightPx =
        (widthPx / template.paper.aspectRatio).round().clamp(1, 4096);
    final decoded = <ui.Image?>[];
    for (final bytes in photoBytes) {
      decoded.add(await _decode(bytes));
    }
    while (decoded.length < template.slotCount) {
      decoded.add(null);
    }

    final assets = <String, ui.Image?>{};
    for (final entry in assetBytes.entries) {
      assets[entry.key] = await _decode(entry.value);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(widthPx.toDouble(), heightPx.toDouble());
    TemplateLayoutPainter(
      template: template,
      context: context,
      photos: decoded,
      assets: assets,
      showPaperBorder: showPaperBorder,
    ).paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(widthPx, heightPx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    for (final p in decoded) {
      p?.dispose();
    }
    for (final a in assets.values) {
      a?.dispose();
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
    this.assets = const {},
    this.height = 240,
    this.showSlotLabels = false,
    this.selectedLayerId,
  });

  final PrintTemplate template;
  final TemplatePrintContext contextData;
  final List<ui.Image?> photos;
  final Map<String, ui.Image?> assets;
  final double height;
  final bool showSlotLabels;
  final String? selectedLayerId;

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
                assets: assets,
                showPaperBorder: false,
                showSlotLabels: showSlotLabels,
                selectedLayerId: selectedLayerId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
