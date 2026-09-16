import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

IconData layerTypeIcon(TemplateLayerType type) {
  switch (type) {
    case TemplateLayerType.photoSlot:
      return Icons.photo_outlined;
    case TemplateLayerType.image:
      return Icons.image_outlined;
    case TemplateLayerType.text:
      return Icons.title;
    case TemplateLayerType.qr:
      return Icons.qr_code_2;
    case TemplateLayerType.shape:
      return Icons.crop_square;
    case TemplateLayerType.background:
      return Icons.wallpaper_outlined;
  }
}

class TemplateLayerListPanel extends StatelessWidget {
  const TemplateLayerListPanel({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final TemplateEditorController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layers = controller.template.layers;
        // Show top of z-order first (last in list = front).
        final display = layers.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Capas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Añadir',
                    onPressed: () => showAddLayerSheet(context, controller),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            if (layers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Añade un fondo o un hueco de foto',
                  style: TextStyle(color: AppColors.grey),
                ),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: display.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    // display is reversed; map back to model indices.
                    final fromModel = layers.length - 1 - oldIndex;
                    var toDisplay = newIndex;
                    if (toDisplay > oldIndex) toDisplay -= 1;
                    final toModel = layers.length - 1 - toDisplay;
                    controller.moveLayerToIndex(fromModel, toModel);
                  },
                  itemBuilder: (context, index) {
                    final layer = display[index];
                    final selected = layer.id == controller.selectedLayerId;
                    return Material(
                      key: ValueKey(layer.id),
                      color: selected
                          ? AppColors.red.withValues(alpha: 0.08)
                          : AppColors.white,
                      child: ListTile(
                        onTap: () => controller.selectLayer(layer.id),
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                        title: Text(
                          layer.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          layer.type.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: layer.visible ? 'Ocultar' : 'Mostrar',
                              onPressed: () =>
                                  controller.toggleVisible(layer.id),
                              icon: Icon(
                                layer.visible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            IconButton(
                              tooltip:
                                  layer.locked ? 'Desbloquear' : 'Bloquear',
                              onPressed: () => controller.toggleLock(layer.id),
                              icon: Icon(
                                layer.locked
                                    ? Icons.lock_outline
                                    : Icons.lock_open_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: controller.applyStarterOneSlot,
                      child: const Text('1 hueco'),
                    ),
                    OutlinedButton(
                      onPressed: controller.applyStarterStrip,
                      child: const Text('Tira'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> showAddLayerSheet(
  BuildContext context,
  TemplateEditorController controller, {
  Future<void> Function()? onPickImage,
  Future<void> Function()? onPickBackground,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      Widget tile({
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
        return ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.red),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(
              icon: Icons.photo_outlined,
              label: 'Hueco de foto',
              onTap: () {
                controller.setDrawSlotMode(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Dibuja los huecos donde deben ir las fotos',
                    ),
                  ),
                );
              },
            ),
            tile(
              icon: Icons.image_outlined,
              label: 'Imagen / logo',
              onTap: () {
                if (onPickImage != null) {
                  onPickImage();
                } else {
                  controller.addLayer(controller.newImage());
                }
              },
            ),
            tile(
              icon: Icons.title,
              label: 'Texto',
              onTap: () => controller.addLayer(controller.newText()),
            ),
            tile(
              icon: Icons.qr_code_2,
              label: 'QR',
              onTap: () => controller.addLayer(controller.newQr()),
            ),
            tile(
              icon: Icons.crop_square,
              label: 'Forma (rectángulo)',
              onTap: () => controller.addLayer(controller.newShape()),
            ),
            tile(
              icon: Icons.circle_outlined,
              label: 'Forma (círculo)',
              onTap: () =>
                  controller.addLayer(controller.newShape(kind: 'circle')),
            ),
            tile(
              icon: Icons.wallpaper_outlined,
              label: 'Fondo (imagen o color)',
              onTap: () {
                if (onPickBackground != null) {
                  onPickBackground();
                } else {
                  controller.addLayer(
                    controller.newBackground(fillColor: '#FFFFFF'),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}
