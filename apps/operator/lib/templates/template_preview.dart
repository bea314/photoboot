import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

/// Simple JSON → thumbnail painter for the Gestión hub (T2).
class TemplatePreviewPainter extends CustomPainter {
  TemplatePreviewPainter(this.template);

  final PrintTemplate template;

  @override
  void paint(Canvas canvas, Size size) {
    final paperAspect = template.paper.aspectRatio;
    final fitted = _fitPaper(size, paperAspect);
    final bg = Paint()..color = AppColors.white;
    final border = Paint()
      ..color = AppColors.red.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(fitted, bg);
    canvas.drawRect(fitted, border);

    for (final layer in template.layers) {
      final rect = Rect.fromLTWH(
        fitted.left + layer.x * fitted.width,
        fitted.top + layer.y * fitted.height,
        layer.w * fitted.width,
        layer.h * fitted.height,
      );
      _paintLayer(canvas, rect, layer);
    }
  }

  void _paintLayer(Canvas canvas, Rect rect, TemplateLayer layer) {
    switch (layer.type) {
      case TemplateLayerType.photoSlot:
        final fill = Paint()..color = AppColors.red.withValues(alpha: 0.1);
        final stroke = Paint()
          ..color = AppColors.red.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
        _drawCenteredIcon(canvas, rect, Icons.photo_outlined, 0.35);
      case TemplateLayerType.image:
        final fill = Paint()..color = AppColors.surface;
        final stroke = Paint()
          ..color = AppColors.grey.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          stroke,
        );
        _drawCenteredIcon(canvas, rect, Icons.image_outlined, 0.45);
      case TemplateLayerType.text:
        final bar = Paint()..color = AppColors.black.withValues(alpha: 0.12);
        final h = (rect.height * 0.35).clamp(2.0, 8.0);
        final textRect = Rect.fromCenter(
          center: rect.center,
          width: rect.width * 0.85,
          height: h,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(textRect, const Radius.circular(2)),
          bar,
        );
      case TemplateLayerType.qr:
        final fill = Paint()..color = AppColors.black.withValues(alpha: 0.08);
        final stroke = Paint()
          ..color = AppColors.black.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        // Simple QR-like grid hint.
        final grid = Paint()
          ..color = AppColors.black.withValues(alpha: 0.35)
          ..strokeWidth = 1;
        final step = rect.shortestSide / 5;
        for (var i = 1; i < 5; i++) {
          final dx = rect.left + step * i;
          final dy = rect.top + step * i;
          canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), grid);
          canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), grid);
        }
    }
  }

  void _drawCenteredIcon(
    Canvas canvas,
    Rect rect,
    IconData icon,
    double scale,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: rect.shortestSide * scale,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: AppColors.red.withValues(alpha: 0.55),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        rect.center.dx - tp.width / 2,
        rect.center.dy - tp.height / 2,
      ),
    );
  }

  Rect _fitPaper(Size size, double aspect) {
    final margin = size.shortestSide * 0.08;
    final avail = Size(size.width - margin * 2, size.height - margin * 2);
    late Size paper;
    if (avail.width / avail.height > aspect) {
      paper = Size(avail.height * aspect, avail.height);
    } else {
      paper = Size(avail.width, avail.width / aspect);
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: paper.width,
      height: paper.height,
    );
  }

  @override
  bool shouldRepaint(covariant TemplatePreviewPainter oldDelegate) {
    return oldDelegate.template.id != template.id ||
        oldDelegate.template.layers.length != template.layers.length ||
        oldDelegate.template.isActive != template.isActive;
  }
}

/// Widget wrapper used on hub cards.
class TemplatePreviewThumb extends StatelessWidget {
  const TemplatePreviewThumb({super.key, required this.template});

  final PrintTemplate template;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: CustomPaint(
        painter: TemplatePreviewPainter(template),
        child: const SizedBox.expand(),
      ),
    );
  }
}
