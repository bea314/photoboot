import 'package:fotoboot_operator/models/print_template.dart';

/// Paper presets for the Nueva plantilla wizard (Corte B).
class PaperPreset {
  const PaperPreset({
    required this.id,
    required this.label,
    required this.paper,
    this.hint,
  });

  final String id;
  final String label;
  final TemplatePaper paper;
  final String? hint;

  static const List<PaperPreset> all = [
    PaperPreset(
      id: 'thermal58',
      label: 'Térmica 58 mm',
      paper: TemplatePaper(
        widthMm: 58,
        heightMm: 100,
        family: PaperFamily.thermal,
      ),
      hint: 'Alto dinámico según contenido',
    ),
    PaperPreset(
      id: 'thermal80',
      label: 'Térmica 80 mm',
      paper: TemplatePaper(
        widthMm: 80,
        heightMm: 100,
        family: PaperFamily.thermal,
      ),
      hint: 'Alto dinámico según contenido',
    ),
    PaperPreset(
      id: 'photo10x15',
      label: '10×15 cm',
      paper: TemplatePaper(
        widthMm: 100,
        heightMm: 150,
        family: PaperFamily.photo,
      ),
    ),
    PaperPreset(
      id: 'photo4x6',
      label: '4×6 in',
      paper: TemplatePaper(
        widthMm: 101.6,
        heightMm: 152.4,
        family: PaperFamily.photo,
      ),
    ),
    PaperPreset(
      id: 'letter',
      label: 'Carta',
      paper: TemplatePaper(
        widthMm: 215.9,
        heightMm: 279.4,
        family: PaperFamily.photo,
      ),
    ),
    PaperPreset(
      id: 'a4',
      label: 'A4',
      paper: TemplatePaper(
        widthMm: 210,
        heightMm: 297,
        family: PaperFamily.photo,
      ),
    ),
  ];
}

/// Default safe-area inset in mm by paper family.
double safeAreaMmFor(TemplatePaper paper) {
  switch (paper.family) {
    case PaperFamily.thermal:
      return 2;
    case PaperFamily.photo:
      if (paper.widthMm >= 200) return 8;
      return 5;
  }
}
