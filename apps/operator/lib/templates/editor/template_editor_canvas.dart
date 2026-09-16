import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/templates/paper_presets.dart';
import 'package:fotoboot_operator/templates/template_composer.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

enum _Handle { move, nw, ne, sw, se, n, s, e, w }

/// Interactive paper canvas: select / move / resize + pinch zoom viewport.
class TemplateEditorCanvas extends StatefulWidget {
  const TemplateEditorCanvas({
    super.key,
    required this.controller,
    required this.printContext,
    this.photos = const [],
    this.assets = const {},
  });

  final TemplateEditorController controller;
  final TemplatePrintContext printContext;
  final List<ui.Image?> photos;
  final Map<String, ui.Image?> assets;

  @override
  State<TemplateEditorCanvas> createState() => _TemplateEditorCanvasState();
}

class _TemplateEditorCanvasState extends State<TemplateEditorCanvas> {
  final _transform = TransformationController();
  _Handle? _activeHandle;
  Offset? _drawStart;
  Rect? _drawRect;
  TemplateLayer? _gestureLayer;
  Offset? _moveGrabNorm; // pointer offset inside layer at gesture start

  static const _handleVisual = 12.0;
  static const _handleHit = 28.0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final template = widget.controller.template;
        return ColoredBox(
          color: const Color(0xFFF0F0F0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                transformationController: _transform,
                minScale: 0.4,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(200),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: template.paper.aspectRatio,
                        child: LayoutBuilder(
                          builder: (context, paperConstraints) {
                            final paperSize = Size(
                              paperConstraints.maxWidth,
                              paperConstraints.maxHeight,
                            );
                            return _buildPaper(paperSize, template);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPaper(Size paperSize, PrintTemplate template) {
    final safeMm = safeAreaMmFor(template.paper);
    final insetX = safeMm / template.paper.widthMm;
    final insetY = safeMm / template.paper.heightMm;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _onDown(e.localPosition, paperSize),
      onPointerMove: (e) => _onMove(e.localPosition, paperSize),
      onPointerUp: (_) => _onUp(paperSize),
      onPointerCancel: (_) => _onUp(paperSize),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: TemplateLayoutPainter(
                template: template,
                context: widget.printContext,
                photos: widget.photos,
                assets: widget.assets,
                showPaperBorder: false,
                showSlotLabels: true,
                selectedLayerId: widget.controller.selectedLayerId,
              ),
            ),
            CustomPaint(
              painter: _SafeAreaPainter(
                insetX: insetX,
                insetY: insetY,
              ),
            ),
            if (_drawRect != null)
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                  _drawRect!.left * paperSize.width,
                  _drawRect!.top * paperSize.height,
                  _drawRect!.width * paperSize.width,
                  _drawRect!.height * paperSize.height,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.red, width: 2),
                    color: AppColors.red.withValues(alpha: 0.12),
                  ),
                ),
              ),
            if (widget.controller.selectedLayer != null &&
                widget.controller.selectedLayer!.visible)
              ..._buildHandles(
                widget.controller.selectedLayer!,
                paperSize,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHandles(TemplateLayer layer, Size paperSize) {
    final rect = Rect.fromLTWH(
      layer.x * paperSize.width,
      layer.y * paperSize.height,
      layer.w * paperSize.width,
      layer.h * paperSize.height,
    );
    final points = <_Handle, Offset>{
      _Handle.nw: rect.topLeft,
      _Handle.ne: rect.topRight,
      _Handle.sw: rect.bottomLeft,
      _Handle.se: rect.bottomRight,
      _Handle.n: Offset(rect.center.dx, rect.top),
      _Handle.s: Offset(rect.center.dx, rect.bottom),
      _Handle.w: Offset(rect.left, rect.center.dy),
      _Handle.e: Offset(rect.right, rect.center.dy),
    };
    return [
      Positioned.fromRect(
        rect: rect,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.red, width: 2),
            ),
          ),
        ),
      ),
      for (final entry in points.entries)
        Positioned(
          left: entry.value.dx - _handleVisual / 2,
          top: entry.value.dy - _handleVisual / 2,
          width: _handleVisual,
          height: _handleVisual,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.red, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ];
  }

  void _onDown(Offset local, Size paperSize) {
    final c = widget.controller;
    final norm = Offset(local.dx / paperSize.width, local.dy / paperSize.height);

    if (c.drawSlotMode) {
      _drawStart = norm;
      _drawRect = Rect.fromPoints(norm, norm);
      setState(() {});
      return;
    }

    final selected = c.selectedLayer;
    if (selected != null && !selected.locked) {
      final handle = _hitHandle(selected, local, paperSize);
      if (handle != null) {
        _activeHandle = handle;
        _gestureLayer = selected;
        c.beginGesture();
        return;
      }
      if (_hitLayer(selected, norm)) {
        _activeHandle = _Handle.move;
        _gestureLayer = selected;
        _moveGrabNorm = Offset(norm.dx - selected.x, norm.dy - selected.y);
        c.beginGesture();
        return;
      }
    }

    // Hit test top-most unlocked/visible layer.
    for (final layer in c.template.layers.reversed) {
      if (!layer.visible) continue;
      if (_hitLayer(layer, norm)) {
        c.selectLayer(layer.id);
        if (!layer.locked) {
          _activeHandle = _Handle.move;
          _gestureLayer = layer;
          _moveGrabNorm = Offset(norm.dx - layer.x, norm.dy - layer.y);
          c.beginGesture();
        }
        return;
      }
    }
    c.selectLayer(null);
  }

  void _onMove(Offset local, Size paperSize) {
    final c = widget.controller;
    final norm = Offset(
      (local.dx / paperSize.width).clamp(0.0, 1.0),
      (local.dy / paperSize.height).clamp(0.0, 1.0),
    );

    if (c.drawSlotMode && _drawStart != null) {
      _drawRect = Rect.fromPoints(_drawStart!, norm).normalize;
      setState(() {});
      return;
    }

    final base = _gestureLayer;
    final handle = _activeHandle;
    if (base == null || handle == null) return;

    TemplateLayer next;
    if (handle == _Handle.move) {
      final current = c.selectedLayer ?? base;
      final grab = _moveGrabNorm ?? Offset(current.w / 2, current.h / 2);
      next = current.copyWith(
        x: (norm.dx - grab.dx).clamp(0.0, 1.0 - current.w),
        y: (norm.dy - grab.dy).clamp(0.0, 1.0 - current.h),
      );
      next = _snapLayer(next, c.template);
    } else {
      next = _resize(base: c.selectedLayer ?? base, handle: handle, norm: norm);
      next = _snapLayer(next, c.template);
    }
    c.mutateLayerLive(next);
  }

  void _onUp(Size paperSize) {
    final c = widget.controller;
    if (c.drawSlotMode && _drawRect != null) {
      final r = _drawRect!;
      if (r.width > 0.02 && r.height > 0.02) {
        final slot =
            c.newPhotoSlot(x: r.left, y: r.top, w: r.width, h: r.height);
        c.addLayer(slot);
      }
      c.setDrawSlotMode(false);
      _drawStart = null;
      _drawRect = null;
      setState(() {});
      return;
    }
    if (_activeHandle != null) {
      c.endGesture();
    }
    _activeHandle = null;
    _gestureLayer = null;
    _moveGrabNorm = null;
  }

  bool _hitLayer(TemplateLayer layer, Offset norm) {
    return norm.dx >= layer.x &&
        norm.dx <= layer.x + layer.w &&
        norm.dy >= layer.y &&
        norm.dy <= layer.y + layer.h;
  }

  _Handle? _hitHandle(TemplateLayer layer, Offset local, Size paperSize) {
    final rect = Rect.fromLTWH(
      layer.x * paperSize.width,
      layer.y * paperSize.height,
      layer.w * paperSize.width,
      layer.h * paperSize.height,
    );
    final points = <_Handle, Offset>{
      _Handle.nw: rect.topLeft,
      _Handle.ne: rect.topRight,
      _Handle.sw: rect.bottomLeft,
      _Handle.se: rect.bottomRight,
      _Handle.n: Offset(rect.center.dx, rect.top),
      _Handle.s: Offset(rect.center.dx, rect.bottom),
      _Handle.w: Offset(rect.left, rect.center.dy),
      _Handle.e: Offset(rect.right, rect.center.dy),
    };
    for (final entry in points.entries) {
      if ((entry.value - local).distance <= _handleHit / 2) {
        return entry.key;
      }
    }
    return null;
  }

  TemplateLayer _resize({
    required TemplateLayer base,
    required _Handle handle,
    required Offset norm,
  }) {
    var left = base.x;
    var top = base.y;
    var right = base.x + base.w;
    var bottom = base.y + base.h;
    const minSize = 0.04;

    switch (handle) {
      case _Handle.nw:
        left = math.min(norm.dx, right - minSize);
        top = math.min(norm.dy, bottom - minSize);
      case _Handle.ne:
        right = math.max(norm.dx, left + minSize);
        top = math.min(norm.dy, bottom - minSize);
      case _Handle.sw:
        left = math.min(norm.dx, right - minSize);
        bottom = math.max(norm.dy, top + minSize);
      case _Handle.se:
        right = math.max(norm.dx, left + minSize);
        bottom = math.max(norm.dy, top + minSize);
      case _Handle.n:
        top = math.min(norm.dy, bottom - minSize);
      case _Handle.s:
        bottom = math.max(norm.dy, top + minSize);
      case _Handle.w:
        left = math.min(norm.dx, right - minSize);
      case _Handle.e:
        right = math.max(norm.dx, left + minSize);
      case _Handle.move:
        break;
    }
    left = left.clamp(0.0, 1.0);
    top = top.clamp(0.0, 1.0);
    right = right.clamp(0.0, 1.0);
    bottom = bottom.clamp(0.0, 1.0);
    return base.copyWith(
      x: left,
      y: top,
      w: (right - left).clamp(minSize, 1.0),
      h: (bottom - top).clamp(minSize, 1.0),
    );
  }

  TemplateLayer _snapLayer(TemplateLayer layer, PrintTemplate template) {
    const threshold = 0.012;
    var x = layer.x;
    var y = layer.y;
    final cx = layer.x + layer.w / 2;
    final cy = layer.y + layer.h / 2;

    // Paper center / edges.
    if ((cx - 0.5).abs() < threshold) x = 0.5 - layer.w / 2;
    if ((cy - 0.5).abs() < threshold) y = 0.5 - layer.h / 2;
    if (x.abs() < threshold) x = 0;
    if (y.abs() < threshold) y = 0;
    if ((x + layer.w - 1).abs() < threshold) x = 1 - layer.w;
    if ((y + layer.h - 1).abs() < threshold) y = 1 - layer.h;

    for (final other in template.layers) {
      if (other.id == layer.id) continue;
      final ocx = other.x + other.w / 2;
      final ocy = other.y + other.h / 2;
      if ((cx - ocx).abs() < threshold) x = ocx - layer.w / 2;
      if ((cy - ocy).abs() < threshold) y = ocy - layer.h / 2;
      if ((layer.x - other.x).abs() < threshold) x = other.x;
      if ((layer.y - other.y).abs() < threshold) y = other.y;
    }

    return layer.copyWith(
      x: x.clamp(0.0, 1.0 - layer.w),
      y: y.clamp(0.0, 1.0 - layer.h),
    );
  }
}

extension on Rect {
  Rect get normalize {
    final l = math.min(left, right);
    final t = math.min(top, bottom);
    final r = math.max(left, right);
    final b = math.max(top, bottom);
    return Rect.fromLTRB(l, t, r, b);
  }
}

class _SafeAreaPainter extends CustomPainter {
  _SafeAreaPainter({required this.insetX, required this.insetY});

  final double insetX;
  final double insetY;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      insetX * size.width,
      insetY * size.height,
      size.width * (1 - insetX),
      size.height * (1 - insetY),
    );
    final paint = Paint()
      ..color = AppColors.grey.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    _dashRect(canvas, rect, paint, dash);
  }

  void _dashRect(Canvas canvas, Rect rect, Paint paint, double dash) {
    void dashLine(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total == 0) return;
      final dir = (b - a) / total;
      var drawn = 0.0;
      var draw = true;
      while (drawn < total) {
        final len = math.min(dash, total - drawn);
        final start = a + dir * drawn;
        final end = a + dir * (drawn + len);
        if (draw) canvas.drawLine(start, end, paint);
        drawn += len;
        draw = !draw;
      }
    }

    dashLine(rect.topLeft, rect.topRight);
    dashLine(rect.topRight, rect.bottomRight);
    dashLine(rect.bottomRight, rect.bottomLeft);
    dashLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant _SafeAreaPainter oldDelegate) {
    return oldDelegate.insetX != insetX || oldDelegate.insetY != insetY;
  }
}

/// Decodes asset map for the editor painter.
Future<Map<String, ui.Image?>> decodeTemplateAssets(
  Map<String, Uint8List> bytes,
) async {
  final out = <String, ui.Image?>{};
  for (final e in bytes.entries) {
    try {
      final codec = await ui.instantiateImageCodec(e.value);
      final frame = await codec.getNextFrame();
      out[e.key] = frame.image;
    } catch (_) {
      out[e.key] = null;
    }
  }
  return out;
}
