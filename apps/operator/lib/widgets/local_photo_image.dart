import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/services/photo_file_store.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class LocalPhotoImage extends StatefulWidget {
  const LocalPhotoImage({
    super.key,
    required this.clientPhotoId,
    required this.files,
    this.thumb = true,
    this.fit = BoxFit.cover,
  });

  final String clientPhotoId;
  final PhotoFileStore files;
  final bool thumb;
  final BoxFit fit;

  @override
  State<LocalPhotoImage> createState() => _LocalPhotoImageState();
}

class _LocalPhotoImageState extends State<LocalPhotoImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant LocalPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientPhotoId != widget.clientPhotoId ||
        oldWidget.thumb != widget.thumb) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() {
    if (widget.thumb) {
      return widget.files.readBest(widget.clientPhotoId);
    }
    return widget.files.readOriginal(widget.clientPhotoId).then(
          (bytes) async => bytes ?? await widget.files.readThumb(widget.clientPhotoId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(
            color: AppColors.surface,
            child: Center(
              child: Icon(Icons.image_outlined, color: AppColors.grey),
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}
