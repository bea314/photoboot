import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class TemplateLayerPropsPanel extends StatelessWidget {
  const TemplateLayerPropsPanel({
    super.key,
    required this.controller,
    this.onReplaceImage,
  });

  final TemplateEditorController controller;
  final VoidCallback? onReplaceImage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final layer = controller.selectedLayer;
        final template = controller.template;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              layer == null ? 'Plantilla' : 'Propiedades',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            if (layer == null) ..._templateProps(context, template) else ...[
              Text(
                layer.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                layer.type.name,
                style: const TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 16),
              ..._layerProps(context, layer),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _templateProps(BuildContext context, PrintTemplate template) {
    return [
      Text('Papel: ${template.paper.label}'),
      const SizedBox(height: 8),
      Text('DPI: ${template.dpi}'),
      const SizedBox(height: 8),
      Text('${template.slotCount} huecos de foto'),
      const SizedBox(height: 16),
      const Text(
        'Toca una capa o añade un hueco de foto.',
        style: TextStyle(color: AppColors.grey),
      ),
    ];
  }

  List<Widget> _layerProps(BuildContext context, TemplateLayer layer) {
    final paper = controller.template.paper;
    final widgets = <Widget>[
      _mmRow(
        label: 'Posición',
        xMm: layer.x * paper.widthMm,
        yMm: layer.y * paper.heightMm,
        onX: (v) => controller.updateLayer(
          layer.copyWith(x: (v / paper.widthMm).clamp(0.0, 1.0)),
        ),
        onY: (v) => controller.updateLayer(
          layer.copyWith(y: (v / paper.heightMm).clamp(0.0, 1.0)),
        ),
      ),
      _mmRow(
        label: 'Tamaño',
        xMm: layer.w * paper.widthMm,
        yMm: layer.h * paper.heightMm,
        xLabel: 'Ancho',
        yLabel: 'Alto',
        onX: (v) => controller.updateLayer(
          layer.copyWith(w: (v / paper.widthMm).clamp(0.04, 1.0)),
        ),
        onY: (v) => controller.updateLayer(
          layer.copyWith(h: (v / paper.heightMm).clamp(0.04, 1.0)),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Bloqueo'),
        value: layer.locked,
        onChanged: (_) => controller.toggleLock(layer.id),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Visible'),
        value: layer.visible,
        onChanged: (_) => controller.toggleVisible(layer.id),
      ),
    ];

    switch (layer.type) {
      case TemplateLayerType.photoSlot:
        widgets.addAll([
          _intField(
            label: 'Índice Foto',
            value: layer.slotIndex ?? 1,
            onChanged: (v) => controller.updateLayer(
              layer.copyWith(slotIndex: v.clamp(1, 32)),
            ),
          ),
          _fitSelector(layer),
        ]);
      case TemplateLayerType.image:
      case TemplateLayerType.background:
        widgets.add(_fitSelector(layer));
        if (onReplaceImage != null) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onReplaceImage,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(
                    layer.type == TemplateLayerType.background
                        ? 'Reemplazar fondo'
                        : 'Reemplazar imagen',
                  ),
                ),
              ),
            ),
          );
        }
      case TemplateLayerType.text:
        widgets.addAll([
          const SizedBox(height: 8),
          _TextContentField(
            layerId: layer.id,
            initialText: layer.text ?? '',
            onCommit: (v) => controller.updateLayer(layer.copyWith(text: v)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final token in [
                '{{evento}}',
                '{{fecha}}',
                '{{hora}}',
                '{{eventUrl}}',
              ])
                ActionChip(
                  label: Text(token),
                  onPressed: () {
                    final next = '${layer.text ?? ''}$token';
                    controller.updateLayer(layer.copyWith(text: next));
                  },
                ),
            ],
          ),
        ]);
      case TemplateLayerType.qr:
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Contenido: URL del evento actual (eventUrl)',
              style: TextStyle(color: AppColors.grey),
            ),
          ),
        );
      case TemplateLayerType.shape:
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              initialValue: layer.shapeKind ?? 'rect',
              decoration: const InputDecoration(
                labelText: 'Forma',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'rect', child: Text('Rectángulo')),
                DropdownMenuItem(value: 'circle', child: Text('Círculo')),
              ],
              onChanged: (v) {
                if (v == null) return;
                controller.updateLayer(layer.copyWith(shapeKind: v));
              },
            ),
          ),
        );
    }

    widgets.addAll([
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: layer.locked
                    ? null
                    : () => controller.duplicateSelected(),
                child: const Text('Duplicar'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: layer.locked
                    ? null
                    : () => controller.removeSelected(),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                child: const Text('Eliminar'),
              ),
            ),
          ),
        ],
      ),
    ]);

    return widgets;
  }

  Widget _fitSelector(TemplateLayer layer) {
    final fit = layer.fit ?? 'cover';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String>(
        initialValue: fit,
        decoration: const InputDecoration(
          labelText: 'Ajuste',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'cover', child: Text('Cover')),
          DropdownMenuItem(value: 'contain', child: Text('Contain')),
          DropdownMenuItem(value: 'fill', child: Text('Fill')),
        ],
        onChanged: (v) {
          if (v == null) return;
          controller.updateLayer(layer.copyWith(fit: v));
        },
      ),
    );
  }

  Widget _intField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: '$value',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (raw) {
          final v = int.tryParse(raw);
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _mmRow({
    required String label,
    required double xMm,
    required double yMm,
    required ValueChanged<double> onX,
    required ValueChanged<double> onY,
    String xLabel = 'X',
    String yLabel = 'Y',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _mmField(label: xLabel, value: xMm, onChanged: onX),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mmField(label: yLabel, value: yMm, onChanged: onY),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mmField({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      key: ValueKey('$label-${value.toStringAsFixed(1)}'),
      initialValue: value.toStringAsFixed(1),
      decoration: InputDecoration(
        labelText: '$label (mm)',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onFieldSubmitted: (raw) {
        final v = double.tryParse(raw.replaceAll(',', '.'));
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TextContentField extends StatefulWidget {
  const _TextContentField({
    required this.layerId,
    required this.initialText,
    required this.onCommit,
  });

  final String layerId;
  final String initialText;
  final ValueChanged<String> onCommit;

  @override
  State<_TextContentField> createState() => _TextContentFieldState();
}

class _TextContentFieldState extends State<_TextContentField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant _TextContentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layerId != widget.layerId ||
        (oldWidget.initialText != widget.initialText &&
            widget.initialText != _controller.text)) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        labelText: 'Contenido',
        border: OutlineInputBorder(),
      ),
      minLines: 2,
      maxLines: 4,
      onEditingComplete: () => widget.onCommit(_controller.text),
      onTapOutside: (_) {
        widget.onCommit(_controller.text);
        FocusScope.of(context).unfocus();
      },
    );
  }
}
