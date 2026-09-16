import 'package:fotoboot_operator/models/print_template.dart';

enum TemplateIssueSeverity { warning, error }

class TemplateIssue {
  const TemplateIssue({
    required this.message,
    required this.severity,
    this.layerId,
  });

  final String message;
  final TemplateIssueSeverity severity;
  final String? layerId;
}

/// Pre-save (draft) and pre-activate validations (Corte B UX §12).
abstract final class TemplateValidation {
  static List<TemplateIssue> draftIssues(PrintTemplate template) {
    final issues = <TemplateIssue>[];
    if (template.name.trim().isEmpty) {
      issues.add(
        const TemplateIssue(
          message: 'Ponle un nombre a la plantilla',
          severity: TemplateIssueSeverity.error,
        ),
      );
    }
    if (template.slotCount == 0) {
      issues.add(
        const TemplateIssue(
          message: 'Podrás imprimir solo el fondo (sin huecos de foto)',
          severity: TemplateIssueSeverity.warning,
        ),
      );
    }
    return issues;
  }

  /// Strict checks before Activar / Usar en este evento.
  static List<TemplateIssue> activateIssues(PrintTemplate template) {
    final issues = <TemplateIssue>[];
    issues.addAll(draftIssues(template).where(
      (i) => i.severity == TemplateIssueSeverity.error,
    ));

    final slots = template.layers
        .where((l) => l.type == TemplateLayerType.photoSlot)
        .toList();

    final seen = <int>{};
    for (final slot in slots) {
      if (slot.w <= 0 || slot.h <= 0) {
        issues.add(
          TemplateIssue(
            message: 'Hay un hueco sin área',
            severity: TemplateIssueSeverity.error,
            layerId: slot.id,
          ),
        );
      }
      final idx = slot.slotIndex;
      if (idx == null) {
        issues.add(
          TemplateIssue(
            message: 'Hay huecos sin número de foto',
            severity: TemplateIssueSeverity.warning,
            layerId: slot.id,
          ),
        );
      } else if (!seen.add(idx)) {
        issues.add(
          TemplateIssue(
            message: 'Hay índices de foto duplicados',
            severity: TemplateIssueSeverity.error,
            layerId: slot.id,
          ),
        );
      }
      if (_outsidePaper(slot)) {
        issues.add(
          TemplateIssue(
            message: 'Un hueco queda fuera del papel',
            severity: TemplateIssueSeverity.error,
            layerId: slot.id,
          ),
        );
      }
    }

    for (final layer in template.layers) {
      if (!layer.visible) continue;
      if (layer.type == TemplateLayerType.qr) {
        final payload = layer.valueKey ?? layer.text;
        if (payload == null || payload.trim().isEmpty) {
          issues.add(
            TemplateIssue(
              message: 'El QR no tiene contenido',
              severity: TemplateIssueSeverity.error,
              layerId: layer.id,
            ),
          );
        }
        final minSide = layer.w < layer.h ? layer.w : layer.h;
        // Rough: < ~15 mm on 100 mm paper ≈ 0.15 normalized.
        if (minSide * template.paper.widthMm < 12) {
          issues.add(
            TemplateIssue(
              message: 'El QR es muy pequeño para leerse bien',
              severity: TemplateIssueSeverity.warning,
              layerId: layer.id,
            ),
          );
        }
      }
      if (layer.type == TemplateLayerType.text &&
          (layer.text == null || layer.text!.trim().isEmpty)) {
        issues.add(
          TemplateIssue(
            message: 'Hay un texto vacío',
            severity: TemplateIssueSeverity.warning,
            layerId: layer.id,
          ),
        );
      }
      if (layer.type == TemplateLayerType.background &&
          layer.assetKey == null &&
          layer.fillColor == null) {
        issues.add(
          TemplateIssue(
            message: 'Falta el fondo importado',
            severity: TemplateIssueSeverity.error,
            layerId: layer.id,
          ),
        );
      }
      if (_outsidePaper(layer) &&
          layer.type != TemplateLayerType.background) {
        issues.add(
          TemplateIssue(
            message: 'Una capa queda fuera del papel',
            severity: TemplateIssueSeverity.error,
            layerId: layer.id,
          ),
        );
      }
    }

    return issues;
  }

  static bool canActivate(PrintTemplate template) {
    return activateIssues(template)
        .every((i) => i.severity != TemplateIssueSeverity.error);
  }

  static bool _outsidePaper(TemplateLayer layer) {
    const eps = 0.001;
    return layer.x < -eps ||
        layer.y < -eps ||
        layer.x + layer.w > 1 + eps ||
        layer.y + layer.h > 1 + eps;
  }
}
