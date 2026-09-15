import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/photo_file_store.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/local_photo_image.dart';
import 'package:fotoboot_operator/widgets/sync_badge.dart';
import 'package:go_router/go_router.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.photos});

  final PhotoController photos;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _confirmDelete(Iterable<String> ids) async {
    final count = ids.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(count == 1 ? 'Eliminar foto' : 'Eliminar $count fotos'),
          content: const Text('Se quitan de la galería y, si ya estaban subidas, del servidor.'),
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
    await widget.photos.deleteMany(ids);
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.photos,
      builder: (context, _) {
        final photos = widget.photos.photos;
        return Scaffold(
          appBar: AppBar(
            title: Text(_selecting ? '${_selected.length} seleccionadas' : 'Galería'),
            leading: _selecting
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_selected.clear),
                  )
                : null,
            actions: [
              if (_selecting)
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmDelete(_selected.toList()),
                  icon: const Icon(Icons.delete_outline),
                )
              else
                IconButton(
                  tooltip: 'Sincronizar',
                  onPressed: widget.photos.syncing ? null : widget.photos.syncNow,
                  icon: widget.photos.syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
            ],
          ),
          body: photos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.photos.error ??
                          'Aún no hay fotos.\nVe a Cámara y dispara.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.grey, fontSize: 18),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.red,
                  onRefresh: widget.photos.syncNow,
                  child: MasonryGridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return _Tile(
                        photo: photo,
                        files: widget.photos.files,
                        selected: _selected.contains(photo.clientPhotoId),
                        selecting: _selecting,
                        onTap: () {
                          if (_selecting) {
                            _toggle(photo.clientPhotoId);
                            return;
                          }
                          context.go('/gallery/detail/${photo.clientPhotoId}');
                        },
                        onLongPress: () => _toggle(photo.clientPhotoId),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.photo,
    required this.files,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final LocalPhoto photo;
  final PhotoFileStore files;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: indexAspect(photo.clientPhotoId),
              child: LocalPhotoImage(
                clientPhotoId: photo.clientPhotoId,
                files: files,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SyncBadge(photo: photo, compact: true),
          ),
          if (selecting)
            Positioned(
              top: 8,
              left: 8,
              child: Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.red : AppColors.white,
              ),
            ),
        ],
      ),
    );
  }
}

double indexAspect(String id) {
  final hash = id.hashCode.abs() % 3;
  return switch (hash) {
    0 => 0.8,
    1 => 1.05,
    _ => 0.92,
  };
}
