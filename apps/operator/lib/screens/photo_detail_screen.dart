import 'package:flutter/material.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/local_photo_image.dart';
import 'package:fotoboot_operator/widgets/sync_badge.dart';
import 'package:go_router/go_router.dart';

class PhotoDetailScreen extends StatelessWidget {
  const PhotoDetailScreen({
    super.key,
    required this.photos,
    required this.clientPhotoId,
  });

  final PhotoController photos;
  final String clientPhotoId;

  String _format(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('Se quita de la galería y del servidor si ya estaba subida.'),
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
    await photos.deleteOne(clientPhotoId);
    if (context.mounted) context.go('/gallery');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: photos,
      builder: (context, _) {
        final photo = photos.byId(clientPhotoId);
        if (photo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle')),
            body: const Center(child: Text('Esta foto ya no está')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Detalle')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: LocalPhotoImage(
                    clientPhotoId: photo.clientPhotoId,
                    files: photos.files,
                    thumb: false,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _format(photo.takenAt),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 12),
              SyncBadge(photo: photo),
              if (photo.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  photo.errorMessage!,
                  style: const TextStyle(color: AppColors.redDark),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _delete(context),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
