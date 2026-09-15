import 'package:flutter/material.dart';
import 'package:fotoboot_operator/services/photo_file_store.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/local_photo_image.dart';

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.clientPhotoId,
    required this.files,
    this.backgroundColor = AppColors.black,
  });

  final String clientPhotoId;
  final PhotoFileStore files;
  final Color backgroundColor;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  final _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void didUpdateWidget(covariant PhotoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientPhotoId != widget.clientPhotoId) {
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final scale = _transform.value.getMaxScaleOnAxis();
    if (scale > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }

    const zoom = 2.6;
    final x = -_doubleTapPosition.dx * (zoom - 1);
    final y = -_doubleTapPosition.dy * (zoom - 1);
    _transform.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(zoom, zoom, zoom, 1);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onDoubleTapDown: (details) {
              _doubleTapPosition = details.localPosition;
            },
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: LocalPhotoImage(
                  clientPhotoId: widget.clientPhotoId,
                  files: widget.files,
                  thumb: false,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
