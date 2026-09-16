import 'dart:typed_data';

import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/services/template_asset_store.dart';
import 'package:fotoboot_operator/templates/template_seed.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Hive-backed local template library (T2 + Corte B drafts).
class TemplateStore {
  TemplateStore({Uuid? uuid, TemplateAssetStore? assets})
      : _uuid = uuid ?? const Uuid(),
        assets = assets ?? TemplateAssetStore();

  static const templatesBoxName = 'templates';
  static const settingsBoxName = 'template_settings';
  static const _activeThermalKey = 'active_thermal';
  static const _activePhotoKey = 'active_photo';
  static const _seededKey = 'seeded_v1';

  final Uuid _uuid;
  final TemplateAssetStore assets;

  late Box _templates;
  late Box _settings;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _templates = Hive.isBoxOpen(templatesBoxName)
        ? Hive.box(templatesBoxName)
        : await Hive.openBox(templatesBoxName);
    _settings = Hive.isBoxOpen(settingsBoxName)
        ? Hive.box(settingsBoxName)
        : await Hive.openBox(settingsBoxName);
    await assets.init();
    await ensureSeeded();
    _ready = true;
  }

  Future<void> ensureSeeded() async {
    final already = _settings.get(_seededKey) == true;
    if (already && _templates.isNotEmpty) return;

    for (final seed in TemplateSeed.all()) {
      if (!_templates.containsKey(seed.id)) {
        await _templates.put(seed.id, seed.toMap());
      }
    }

    if (_settings.get(_activeThermalKey) == null) {
      await _settings.put(
        _activeThermalKey,
        TemplateSeed.defaultActiveThermalId,
      );
    }

    await _settings.put(_seededKey, true);
  }

  String? activeIdFor(PaperFamily family) {
    switch (family) {
      case PaperFamily.thermal:
        return _settings.get(_activeThermalKey) as String?;
      case PaperFamily.photo:
        return _settings.get(_activePhotoKey) as String?;
    }
  }

  Future<void> setActive(String templateId) async {
    final template = getById(templateId);
    if (template == null) return;
    final key = template.paper.family == PaperFamily.thermal
        ? _activeThermalKey
        : _activePhotoKey;
    await _settings.put(key, templateId);
  }

  bool isActive(PrintTemplate template) {
    return activeIdFor(template.paper.family) == template.id;
  }

  List<PrintTemplate> listAll() {
    final items = _templates.values
        .map((raw) {
          final map = Map<String, dynamic>.from(raw as Map);
          final base = PrintTemplate.fromMap(map);
          return base.copyWith(isActive: isActive(base));
        })
        .toList()
      ..sort((a, b) {
        // Active first within family, then name.
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return items;
  }

  PrintTemplate? getById(String id) {
    final raw = _templates.get(id);
    if (raw == null) return null;
    final base = PrintTemplate.fromMap(Map<String, dynamic>.from(raw as Map));
    return base.copyWith(isActive: isActive(base));
  }

  PrintTemplate? activeFor(PaperFamily family) {
    final id = activeIdFor(family);
    if (id == null) return null;
    return getById(id);
  }

  Future<void> upsert(PrintTemplate template) {
    return _templates.put(template.id, template.toMap());
  }

  Future<PrintTemplate> duplicate(String templateId) async {
    final source = getById(templateId);
    if (source == null) {
      throw StateError('Template $templateId not found');
    }
    final copy = source.copyWith(
      id: _uuid.v4(),
      name: '${source.name} (copia)',
      isActive: false,
    );
    await upsert(copy);
    return getById(copy.id)!;
  }

  /// Creates a generic 1-slot (or thermal ticket-foto style) and persists it.
  Future<PrintTemplate> createGeneric({
    required TemplatePaper paper,
    String? name,
  }) async {
    final id = _uuid.v4();
    final label = name ?? 'Plantilla ${paper.label}';
    final created = TemplateSeed.genericOneSlot(
      id: id,
      name: label,
      paper: paper,
    );
    await upsert(created);
    return getById(id)!;
  }

  /// Mode B — blank canvas (optionally with a starter layout later in editor).
  Future<PrintTemplate> createBlank({
    required TemplatePaper paper,
    required String name,
  }) async {
    final id = _uuid.v4();
    final created = PrintTemplate(
      id: id,
      name: name,
      paper: paper,
      layers: const [],
      dpi: paper.family == PaperFamily.thermal ? 203 : 300,
    );
    await upsert(created);
    return getById(id)!;
  }

  /// Mode A — background image + empty slots for the operator to draw.
  Future<PrintTemplate> createWithBackground({
    required TemplatePaper paper,
    required String name,
    required Uint8List backgroundBytes,
  }) async {
    final id = _uuid.v4();
    final assetKey = await assets.putBytes(backgroundBytes);
    final bg = TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.background,
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      fit: 'contain',
      assetKey: assetKey,
      locked: true,
      role: 'background',
      name: 'Fondo',
    );
    final created = PrintTemplate(
      id: id,
      name: name,
      paper: paper,
      layers: [bg],
      dpi: paper.family == PaperFamily.thermal ? 203 : 300,
    );
    await upsert(created);
    return getById(id)!;
  }

  Future<Map<String, Uint8List>> loadAssetsFor(PrintTemplate template) async {
    final out = <String, Uint8List>{};
    for (final layer in template.layers) {
      final key = layer.assetKey;
      if (key == null || out.containsKey(key)) continue;
      final bytes = await assets.read(key);
      if (bytes != null) out[key] = bytes;
    }
    return out;
  }

  Future<void> delete(String id) => _templates.delete(id);
}
