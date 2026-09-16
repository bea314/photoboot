/// Local print-template JSON model (Corte A / T2 + Corte B editor).
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
  qr,
  shape,
  background;

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
    this.name,
    this.fit,
    this.text,
    this.role,
    this.valueKey,
    this.slotIndex,
    this.locked = false,
    this.visible = true,
    this.opacity = 1,
    this.cornerRadius,
    this.fillColor,
    this.strokeColor,
    this.assetKey,
    this.shapeKind,
  });

  final String id;
  final TemplateLayerType type;

  /// Optional display name in the layer list.
  final String? name;

  /// Normalized rect (0–1 of paper).
  final double x;
  final double y;
  final double w;
  final double h;

  /// photoSlot / image / background — `cover` | `contain` | `fill`.
  final String? fit;

  /// text layers (may include `{{fecha}}` / `{{hora}}` placeholders).
  final String? text;

  /// Semantic role: logo, cta, brand, timestamp, url, …
  final String? role;

  /// qr layers — e.g. `eventUrl`.
  final String? valueKey;

  /// photoSlot only — 1-based Foto index. Null = order of appearance.
  final int? slotIndex;

  final bool locked;
  final bool visible;

  /// 0–1.
  final double opacity;

  /// Corner radius as fraction of the shorter side (0–0.5).
  final double? cornerRadius;

  /// Hex `#RRGGBB` or `#AARRGGBB`.
  final String? fillColor;
  final String? strokeColor;

  /// Key in [TemplateAssetStore] for background / image bytes.
  final String? assetKey;

  /// shape only — `rect` | `circle`.
  final String? shapeKind;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    switch (type) {
      case TemplateLayerType.photoSlot:
        final i = slotIndex;
        return i == null ? 'Hueco de foto' : 'Foto $i';
      case TemplateLayerType.image:
        return role == 'logo' ? 'Logo' : 'Imagen';
      case TemplateLayerType.text:
        return 'Texto';
      case TemplateLayerType.qr:
        return 'QR';
      case TemplateLayerType.shape:
        return shapeKind == 'circle' ? 'Círculo' : 'Rectángulo';
      case TemplateLayerType.background:
        return 'Fondo';
    }
  }

  TemplateLayer copyWith({
    String? id,
    TemplateLayerType? type,
    String? name,
    double? x,
    double? y,
    double? w,
    double? h,
    String? fit,
    String? text,
    String? role,
    String? valueKey,
    int? slotIndex,
    bool? locked,
    bool? visible,
    double? opacity,
    double? cornerRadius,
    String? fillColor,
    String? strokeColor,
    String? assetKey,
    String? shapeKind,
    bool clearSlotIndex = false,
    bool clearText = false,
    bool clearAssetKey = false,
    bool clearFit = false,
  }) {
    return TemplateLayer(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      fit: clearFit ? null : (fit ?? this.fit),
      text: clearText ? null : (text ?? this.text),
      role: role ?? this.role,
      valueKey: valueKey ?? this.valueKey,
      slotIndex: clearSlotIndex ? null : (slotIndex ?? this.slotIndex),
      locked: locked ?? this.locked,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      assetKey: clearAssetKey ? null : (assetKey ?? this.assetKey),
      shapeKind: shapeKind ?? this.shapeKind,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      if (name != null) 'name': name,
      if (fit != null) 'fit': fit,
      if (text != null) 'text': text,
      if (role != null) 'role': role,
      if (valueKey != null) 'valueKey': valueKey,
      if (slotIndex != null) 'slotIndex': slotIndex,
      if (locked) 'locked': locked,
      if (!visible) 'visible': visible,
      if (opacity != 1) 'opacity': opacity,
      if (cornerRadius != null) 'cornerRadius': cornerRadius,
      if (fillColor != null) 'fillColor': fillColor,
      if (strokeColor != null) 'strokeColor': strokeColor,
      if (assetKey != null) 'assetKey': assetKey,
      if (shapeKind != null) 'shapeKind': shapeKind,
    };
  }

  factory TemplateLayer.fromMap(Map map) {
    return TemplateLayer(
      id: map['id'] as String,
      type: TemplateLayerType.fromName(map['type'] as String? ?? 'text'),
      name: map['name'] as String?,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      w: (map['w'] as num).toDouble(),
      h: (map['h'] as num).toDouble(),
      fit: map['fit'] as String?,
      text: map['text'] as String?,
      role: map['role'] as String?,
      valueKey: map['valueKey'] as String?,
      slotIndex: (map['slotIndex'] as num?)?.toInt(),
      locked: map['locked'] as bool? ?? false,
      visible: map['visible'] as bool? ?? true,
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1,
      cornerRadius: (map['cornerRadius'] as num?)?.toDouble(),
      fillColor: map['fillColor'] as String?,
      strokeColor: map['strokeColor'] as String?,
      assetKey: map['assetKey'] as String?,
      shapeKind: map['shapeKind'] as String?,
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
    this.dpi = 300,
  });

  final String id;
  final String name;
  final TemplatePaper paper;
  final List<TemplateLayer> layers;

  /// True when this template is the active one for [paper.family].
  final bool isActive;

  /// Raster hint (foto default 300; térmica may use 203).
  final int dpi;

  int get slotCount =>
      layers.where((l) => l.type == TemplateLayerType.photoSlot).length;

  /// photoSlots ordered by [TemplateLayer.slotIndex] then creation order.
  List<TemplateLayer> get orderedPhotoSlots {
    final slots = layers
        .where((l) => l.type == TemplateLayerType.photoSlot)
        .toList();
    final indexed = <TemplateLayer>[];
    final unindexed = <TemplateLayer>[];
    for (final s in slots) {
      if (s.slotIndex != null) {
        indexed.add(s);
      } else {
        unindexed.add(s);
      }
    }
    indexed.sort((a, b) => a.slotIndex!.compareTo(b.slotIndex!));
    return [...indexed, ...unindexed];
  }

  PrintTemplate copyWith({
    String? id,
    String? name,
    TemplatePaper? paper,
    List<TemplateLayer>? layers,
    bool? isActive,
    int? dpi,
  }) {
    return PrintTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      paper: paper ?? this.paper,
      layers: layers ?? this.layers,
      isActive: isActive ?? this.isActive,
      dpi: dpi ?? this.dpi,
    );
  }

  /// Persistable JSON (without transient [isActive]).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'paper': paper.toMap(),
      'layers': layers.map((l) => l.toMap()).toList(),
      if (dpi != 300) 'dpi': dpi,
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
          .map(
            (raw) =>
                TemplateLayer.fromMap(Map<String, dynamic>.from(raw as Map)),
          )
          .toList(),
      isActive: isActive,
      dpi: (map['dpi'] as num?)?.toInt() ?? 300,
    );
  }
}
