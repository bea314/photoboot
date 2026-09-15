import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/photo_download.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/photo_viewer.dart';
import 'package:fotoboot_operator/widgets/sync_badge.dart';
import 'package:go_router/go_router.dart';

Future<void> _savePhotoToDownloads({
  required BuildContext context,
  required PhotoController photos,
  required String clientPhotoId,
}) async {
  try {
    final bytes = await photos.files.readOriginal(clientPhotoId) ??
        await photos.files.readBest(clientPhotoId);
    if (!context.mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el archivo de la foto')),
      );
      return;
    }
    final name = 'fotoboot-${clientPhotoId.substring(0, 8)}.jpg';
    final saved = await downloadPhotoBytes(bytes: bytes, filename: name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Descarga iniciada'
              : 'En este dispositivo la foto ya está guardada en el booth',
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar la foto')),
      );
    }
  }
}

class PhotoDetailScreen extends StatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photos,
    required this.clientPhotoId,
  });

  final PhotoController photos;
  final String clientPhotoId;

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool _infoExpanded = true;
  bool _downloading = false;

  String _format(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text(
            'Se quita de la galería y del servidor si ya estaba subida.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await widget.photos.deleteOne(widget.clientPhotoId);
    if (mounted) context.go('/gallery');
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await _savePhotoToDownloads(
        context: context,
        photos: widget.photos,
        clientPhotoId: widget.clientPhotoId,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _openFullscreen(LocalPhoto photo) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) => _PhotoFullscreenPage(
          photos: widget.photos,
          clientPhotoId: photo.clientPhotoId,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.photos,
      builder: (context, _) {
        final photo = widget.photos.byId(widget.clientPhotoId);
        if (photo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle')),
            body: const Center(child: Text('Esta foto ya no está')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.black,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoViewer(
                      clientPhotoId: photo.clientPhotoId,
                      files: widget.photos.files,
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            _GlassIconButton(
                              tooltip: 'Volver',
                              icon: Icons.arrow_back,
                              onPressed: () => context.go('/gallery'),
                            ),
                            const Spacer(),
                            _GlassIconButton(
                              tooltip: 'Descargar',
                              icon: _downloading
                                  ? Icons.hourglass_top
                                  : Icons.download_outlined,
                              onPressed: _downloading ? null : _download,
                            ),
                            const SizedBox(width: 8),
                            _GlassIconButton(
                              tooltip: 'Pantalla completa',
                              icon: Icons.fullscreen,
                              onPressed: () => _openFullscreen(photo),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _InfoSheet(
                photo: photo,
                expanded: _infoExpanded,
                takenLabel: _format(photo.takenAt),
                printedLabel: photo.printedAt == null
                    ? 'Aún no impresa'
                    : 'Impresa ${_format(photo.printedAt!)}',
                onToggle: () => setState(() => _infoExpanded = !_infoExpanded),
                onDelete: _delete,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.photo,
    required this.expanded,
    required this.takenLabel,
    required this.printedLabel,
    required this.onToggle,
    required this.onDelete,
  });

  final LocalPhoto photo;
  final bool expanded;
  final String takenLabel;
  final String printedLabel;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.46,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggle,
                      onVerticalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity > 240 && expanded) onToggle();
                        if (velocity < -240 && !expanded) onToggle();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.grey.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  takenLabel,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.black,
                                  ),
                                ),
                              ),
                              SyncBadge(photo: photo),
                              const SizedBox(width: 4),
                              Icon(
                                expanded
                                    ? Icons.expand_more
                                    : Icons.expand_less,
                                color: AppColors.red,
                                size: 28,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 16),
                      _MetaRow(
                        icon: Icons.print_outlined,
                        label: printedLabel,
                      ),
                      const SizedBox(height: 8),
                      const _MetaRow(
                        icon: Icons.zoom_in_outlined,
                        label: 'Pellizca o toca dos veces para zoom',
                      ),
                      if (photo.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          photo.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.redDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: onDelete,
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoFullscreenPage extends StatefulWidget {
  const _PhotoFullscreenPage({
    required this.photos,
    required this.clientPhotoId,
  });

  final PhotoController photos;
  final String clientPhotoId;

  @override
  State<_PhotoFullscreenPage> createState() => _PhotoFullscreenPageState();
}

class _PhotoFullscreenPageState extends State<_PhotoFullscreenPage> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await _savePhotoToDownloads(
        context: context,
        photos: widget.photos,
        clientPhotoId: widget.clientPhotoId,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PhotoViewer(
            clientPhotoId: widget.clientPhotoId,
            files: widget.photos.files,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassIconButton(
                        tooltip: 'Cerrar',
                        icon: Icons.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _GlassIconButton(
                        tooltip: 'Descargar',
                        icon: _downloading
                            ? Icons.hourglass_top
                            : Icons.download_outlined,
                        onPressed: _downloading ? null : _download,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const IgnorePointer(
                    child: Text(
                      'Pellizca o toca dos veces para acercar',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 26,
        color: AppColors.red,
        icon: Icon(icon),
      ),
    );
  }
}
