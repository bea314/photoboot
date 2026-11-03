import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fotoboot_operator/templates/template_layer_typography.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

/// Swatches + optional hex field for template layer colors.
class TemplateColorField extends StatelessWidget {
  const TemplateColorField({
    super.key,
    required this.label,
    required this.valueHex,
    required this.onChanged,
    this.allowNone = false,
    this.noneLabel = 'Sin relleno',
  });

  final String label;
  final String? valueHex;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  final String noneLabel;

  static const swatches = <String>[
    '#000000',
    '#FFFFFF',
    '#E10600',
    '#333333',
    '#888888',
    '#FFD700',
    '#0066CC',
  ];

  @override
  Widget build(BuildContext context) {
    final current = valueHex?.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (allowNone)
              _SwatchChip(
                color: Colors.transparent,
                selected: current == null || current.isEmpty,
                label: noneLabel,
                onTap: () => onChanged(null),
              ),
            for (final hex in swatches)
              _SwatchChip(
                color: parseTemplateHex(hex) ?? AppColors.black,
                selected: current == hex.toUpperCase(),
                onTap: () => onChanged(hex),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('$label-$current'),
          initialValue: current ?? '',
          decoration: const InputDecoration(
            labelText: 'Hex',
            hintText: '#RRGGBB',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[#0-9A-Fa-f]')),
          ],
          onFieldSubmitted: (raw) {
            final trimmed = raw.trim();
            if (trimmed.isEmpty) {
              if (allowNone) onChanged(null);
              return;
            }
            final normalized = trimmed.startsWith('#') ? trimmed : '#$trimmed';
            if (parseTemplateHex(normalized) != null) {
              onChanged(normalized.toUpperCase());
            }
          },
        ),
      ],
    );
  }
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return ChoiceChip(
        label: Text(label!),
        selected: selected,
        onSelected: (_) => onTap(),
      );
    }
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppColors.red : AppColors.grey.withValues(alpha: 0.4),
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }
}
