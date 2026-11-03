import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/editor/template_color_field.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/templates/template_layer_typography.dart';
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
          _TextPresetRow(
            layer: layer,
            onPreset: (preset) =>
                controller.applyTextPresetToSelected(preset),
          ),
          const SizedBox(height: 8),
          _TextContentField(
            layerId: layer.id,
            initialText: layer.text ?? '',
            onCommit: (v) => controller.updateLayer(layer.copyWith(text: v)),
          ),
          const SizedBox(height: 12),
          _TextTypographyFields(
            layer: layer,
            paper: paper,
            onUpdate: (next) => controller.updateLayer(next),
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
        widgets.addAll([
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey('shape-${layer.id}-${layer.shapeKind}'),
              initialValue: layer.shapeKind ?? 'rect',
              decoration: const InputDecoration(
                labelText: 'Forma',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'rect', child: Text('Rectángulo')),
                DropdownMenuItem(
                  value: 'roundedRect',
                  child: Text('Rect redondeado'),
                ),
                DropdownMenuItem(value: 'circle', child: Text('Círculo')),
                DropdownMenuItem(value: 'line', child: Text('Línea / divisor')),
              ],
              onChanged: (v) {
                if (v == null) return;
                controller.updateLayer(layer.copyWith(shapeKind: v));
              },
            ),
          ),
          const SizedBox(height: 12),
          TemplateColorField(
            label: 'Relleno',
            valueHex: layer.fillColor,
            allowNone: true,
            onChanged: (hex) {
              controller.updateLayer(
                hex == null
                    ? layer.copyWith(clearFillColor: true)
                    : layer.copyWith(fillColor: hex),
              );
            },
          ),
          const SizedBox(height: 12),
          TemplateColorField(
            label: 'Borde',
            valueHex: layer.strokeColor,
            allowNone: true,
            noneLabel: 'Sin borde',
            onChanged: (hex) {
              controller.updateLayer(
                hex == null
                    ? layer.copyWith(clearStrokeColor: true)
                    : layer.copyWith(strokeColor: hex),
              );
            },
          ),
          _mmSlider(
            label: 'Grosor borde (mm)',
            value: layer.strokeWidthMm ?? 0.25,
            min: 0.1,
            max: 2,
            onChanged: (v) =>
                controller.updateLayer(layer.copyWith(strokeWidthMm: v)),
          ),
          _normalizedSlider(
            label: 'Radio esquina',
            value: layer.cornerRadius ?? 0,
            enabled: layer.shapeKind == 'rect' ||
                layer.shapeKind == 'roundedRect' ||
                layer.shapeKind == null,
            onChanged: (v) =>
                controller.updateLayer(layer.copyWith(cornerRadius: v)),
          ),
          _opacitySlider(
            layer,
            onChanged: (v) =>
                controller.updateLayer(layer.copyWith(opacity: v)),
          ),
        ]);
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

class _TextPresetRow extends StatelessWidget {
  const _TextPresetRow({
    required this.layer,
    required this.onPreset,
  });

  final TemplateLayer layer;
  final ValueChanged<TemplateTextPresetId> onPreset;

  @override
  Widget build(BuildContext context) {
    final detected = TemplateTextPresets.detect(layer);
    return Wrap(
      spacing: 8,
      children: [
        for (final id in TemplateTextPresetId.values)
          ChoiceChip(
            label: Text(TemplateTextPresets.label(id)),
            selected: detected == id,
            onSelected: (_) => onPreset(id),
          ),
      ],
    );
  }
}

class _TextTypographyFields extends StatelessWidget {
  const _TextTypographyFields({
    required this.layer,
    required this.paper,
    required this.onUpdate,
  });

  final TemplateLayer layer;
  final TemplatePaper paper;
  final ValueChanged<TemplateLayer> onUpdate;

  @override
  Widget build(BuildContext context) {
    final pt = layer.fontSizePt ?? 9;
    final weight = layer.fontWeight ?? 'regular';
    final align = layer.textAlign ?? 'center';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipografía',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text('Tamaño ${pt.toStringAsFixed(1)} pt'),
            ),
            SizedBox(
              width: 120,
              child: TextFormField(
                key: ValueKey('pt-${layer.id}-$pt'),
                initialValue: pt.toStringAsFixed(1),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  suffixText: 'pt',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onFieldSubmitted: (raw) {
                  final v = double.tryParse(raw.replaceAll(',', '.'));
                  if (v != null) {
                    onUpdate(layer.copyWith(fontSizePt: v.clamp(6, 48)));
                  }
                },
              ),
            ),
          ],
        ),
        Slider(
          value: pt.clamp(6, 48),
          min: 6,
          max: 48,
          divisions: 84,
          label: '${pt.toStringAsFixed(1)} pt',
          onChanged: (v) => onUpdate(layer.copyWith(fontSizePt: v)),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('weight-${layer.id}-$weight'),
          initialValue: weight,
          decoration: const InputDecoration(
            labelText: 'Peso',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'regular', child: Text('Regular')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'bold', child: Text('Bold')),
          ],
          onChanged: (v) {
            if (v == null) return;
            onUpdate(layer.copyWith(fontWeight: v));
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('font-${layer.id}-${layer.fontFamily}'),
          initialValue: TemplateFontCatalog.resolve(layer.fontFamily),
          decoration: const InputDecoration(
            labelText: 'Fuente',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final e in TemplateFontCatalog.entries.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v == null) return;
            onUpdate(layer.copyWith(fontFamily: v));
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
            ButtonSegment(
              value: 'center',
              icon: Icon(Icons.format_align_center),
            ),
            ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
          ],
          selected: {align},
          onSelectionChanged: (set) {
            onUpdate(layer.copyWith(textAlign: set.first));
          },
        ),
        const SizedBox(height: 12),
        TemplateColorField(
          label: 'Color',
          valueHex: layer.color ?? '#000000',
          onChanged: (hex) {
            if (hex == null) {
              onUpdate(layer.copyWith(clearColor: true));
            } else {
              onUpdate(layer.copyWith(color: hex));
            }
          },
        ),
        const SizedBox(height: 8),
        _intField(
          label: 'Máx. líneas',
          value: layer.maxLines ?? 2,
          onChanged: (v) => onUpdate(layer.copyWith(maxLines: v.clamp(1, 12))),
        ),
      ],
    );
  }

  Widget _intField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
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
    );
  }
}

Widget _mmSlider({
  required String label,
  required double value,
  required double min,
  required double max,
  required ValueChanged<double> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.toStringAsFixed(2)}'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    ],
  );
}

Widget _normalizedSlider({
  required String label,
  required double value,
  required ValueChanged<double> onChanged,
  bool enabled = true,
}) {
  return Opacity(
    opacity: enabled ? 1 : 0.4,
    child: IgnorePointer(
      ignoring: !enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${(value * 100).toStringAsFixed(0)} %'),
          Slider(
            value: value.clamp(0, 0.5),
            min: 0,
            max: 0.5,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

Widget _opacitySlider(
  TemplateLayer layer, {
  required ValueChanged<double> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Opacidad: ${(layer.opacity * 100).round()} %'),
      Slider(
        value: layer.opacity.clamp(0, 1),
        min: 0,
        max: 1,
        onChanged: onChanged,
      ),
    ],
  );
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
