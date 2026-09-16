/// Local print-template JSON model (Corte A / T2).
/// Coordinates are normalized 0–1 relative to the paper rectangle.
library;

enum PaperFamily {
  thermal,
  photo;

  static PaperFamily fromName(String raw) {
    return PaperFamily.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => PaperFamily.thermal,
    );
  }
}

enum TemplateLayerType {
  photoSlot,
  image,
  text,
  qr;

  static TemplateLayerType fromName(String raw) {
    return TemplateLayerType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => TemplateLayerType.text,
    );
  }
}

class TemplatePaper {
  const TemplatePaper({
    required this.widthMm,
    required this.heightMm,
    required this.family,
  });

  final double widthMm;
  final double heightMm;
  final PaperFamily family;

  double get aspectRatio => widthMm / heightMm;

  String get label {
    switch (family) {
      case PaperFamily.thermal:
        return 'Térmica ${widthMm.toStringAsFixed(0)} mm';
      case PaperFamily.photo:
        final wCm = widthMm / 10;
        final hCm = heightMm / 10;
        final wLabel = wCm == wCm.roundToDouble()
            ? wCm.toStringAsFixed(0)
            : wCm.toStringAsFixed(1);
        final hLabel = hCm == hCm.roundToDouble()
            ? hCm.toStringAsFixed(0)
            : hCm.toStringAsFixed(1);
        return '$wLabel×$hLabel cm';
    }
  }

  Map<String, dynamic> toMap() => {
        'widthMm': widthMm,
        'heightMm': heightMm,
        'family': family.name,
      };

  factory TemplatePaper.fromMap(Map map) {
    return TemplatePaper(
      widthMm: (map['widthMm'] as num).toDouble(),
      heightMm: (map['heightMm'] as num).toDouble(),
      family: PaperFamily.fromName(map['family'] as String? ?? 'thermal'),
    );
  }
}

class TemplateLayer {
  const TemplateLayer({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.fit,
    this.text,
    this.role,
    this.valueKey,
  });

  final String id;
  final TemplateLayerType type;

  /// Normalized rect (0–1 of paper).
  final double x;
  final double y;
  final double w;
  final double h;

  /// photoSlot only — typically `cover`.
  final String? fit;

  /// text layers (may include `{{fecha}}` / `{{hora}}` placeholders).
  final String? text;

  /// Semantic role: logo, cta, brand, timestamp, url, …
  final String? role;

  /// qr layers — e.g. `eventUrl`.
  final String? valueKey;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      if (fit != null) 'fit': fit,
      if (text != null) 'text': text,
      if (role != null) 'role': role,
      if (valueKey != null) 'valueKey': valueKey,
    };
  }

  factory TemplateLayer.fromMap(Map map) {
    return TemplateLayer(
      id: map['id'] as String,
      type: TemplateLayerType.fromName(map['type'] as String? ?? 'text'),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      w: (map['w'] as num).toDouble(),
      h: (map['h'] as num).toDouble(),
      fit: map['fit'] as String?,
      text: map['text'] as String?,
      role: map['role'] as String?,
      valueKey: map['valueKey'] as String?,
    );
  }
}

/// UX-facing plantilla. [isActive] is per paper family (not a single global).
class PrintTemplate {
  const PrintTemplate({
    required this.id,
    required this.name,
    required this.paper,
    required this.layers,
    this.isActive = false,
  });

  final String id;
  final String name;
  final TemplatePaper paper;
  final List<TemplateLayer> layers;

  /// True when this template is the active one for [paper.family].
  final bool isActive;

  int get slotCount =>
      layers.where((l) => l.type == TemplateLayerType.photoSlot).length;

  PrintTemplate copyWith({
    String? id,
    String? name,
    TemplatePaper? paper,
    List<TemplateLayer>? layers,
    bool? isActive,
  }) {
    return PrintTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      paper: paper ?? this.paper,
      layers: layers ?? this.layers,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Persistable JSON (without transient [isActive]).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'paper': paper.toMap(),
      'layers': layers.map((l) => l.toMap()).toList(),
    };
  }

  factory PrintTemplate.fromMap(Map map, {bool isActive = false}) {
    final rawLayers = map['layers'] as List? ?? const [];
    return PrintTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      paper: TemplatePaper.fromMap(
        Map<String, dynamic>.from(map['paper'] as Map),
      ),
      layers: rawLayers
          .map((raw) => TemplateLayer.fromMap(Map<String, dynamic>.from(raw as Map)))
          .toList(),
      isActive: isActive,
    );
  }
}
