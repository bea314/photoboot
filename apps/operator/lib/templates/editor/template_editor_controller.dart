import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:uuid/uuid.dart';

/// Undo/redo + selection state for the template editor (Corte B).
class TemplateEditorController extends ChangeNotifier {
  TemplateEditorController({
    required PrintTemplate initial,
    Uuid? uuid,
  })  : _uuid = uuid ?? const Uuid(),
        _template = initial,
        _undo = [],
        _redo = [];

  final Uuid _uuid;
  PrintTemplate _template;
  final List<PrintTemplate> _undo;
  final List<PrintTemplate> _redo;
  String? _selectedLayerId;
  bool _dirty = false;
  DateTime? _lastSavedAt;
  bool _saving = false;
  String? _saveError;

  /// When non-null, the next drag on empty canvas draws a photoSlot.
  bool drawSlotMode = false;

  PrintTemplate get template => _template;
  String? get selectedLayerId => _selectedLayerId;
  bool get dirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  DateTime? get lastSavedAt => _lastSavedAt;
  bool get saving => _saving;
  String? get saveError => _saveError;

  TemplateLayer? get selectedLayer {
    final id = _selectedLayerId;
    if (id == null) return null;
    for (final l in _template.layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  void markSaved() {
    _dirty = false;
    _saving = false;
    _saveError = null;
    _lastSavedAt = DateTime.now();
    notifyListeners();
  }

  void markSaving() {
    _saving = true;
    _saveError = null;
    notifyListeners();
  }

  void markSaveError(String message) {
    _saving = false;
    _saveError = message;
    notifyListeners();
  }

  void selectLayer(String? id) {
    if (_selectedLayerId == id) return;
    _selectedLayerId = id;
    notifyListeners();
  }

  void setDrawSlotMode(bool enabled) {
    if (drawSlotMode == enabled) return;
    drawSlotMode = enabled;
    notifyListeners();
  }

  void rename(String name) {
    _commit(_template.copyWith(name: name));
  }

  void setPaper(TemplatePaper paper) {
    _commit(_template.copyWith(paper: paper));
  }

  void updateLayer(TemplateLayer layer, {bool pushHistory = true}) {
    final layers = _template.layers
        .map((l) => l.id == layer.id ? layer : l)
        .toList();
    final next = _template.copyWith(layers: layers);
    if (pushHistory) {
      _commit(next);
    } else {
      _template = next;
      _dirty = true;
      notifyListeners();
    }
  }

  /// Live drag/resize without flooding the undo stack.
  void mutateLayerLive(TemplateLayer layer) {
    updateLayer(layer, pushHistory: false);
  }

  void commitLiveMutation() {
    // Snapshot current as undoable by pushing previous baseline.
    // Callers should [beginGesture] first; if not, treat current as committed.
    _dirty = true;
    notifyListeners();
  }

  PrintTemplate? _gestureBaseline;

  void beginGesture() {
    _gestureBaseline = _template;
  }

  void endGesture() {
    final baseline = _gestureBaseline;
    _gestureBaseline = null;
    if (baseline == null) return;
    if (baseline.toMap().toString() == _template.toMap().toString()) return;
    _undo.add(baseline);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    _dirty = true;
    notifyListeners();
  }

  void addLayer(TemplateLayer layer, {bool select = true}) {
    _commit(_template.copyWith(layers: [..._template.layers, layer]));
    if (select) _selectedLayerId = layer.id;
  }

  void removeSelected() {
    final id = _selectedLayerId;
    if (id == null) return;
    final layer = selectedLayer;
    if (layer == null || layer.locked) return;
    _commit(
      _template.copyWith(
        layers: _template.layers.where((l) => l.id != id).toList(),
      ),
    );
    _selectedLayerId = null;
    _renumberSlots();
  }

  void removeLayer(String id) {
    TemplateLayer? layer;
    for (final l in _template.layers) {
      if (l.id == id) {
        layer = l;
        break;
      }
    }
    if (layer == null || layer.locked) return;
    _commit(
      _template.copyWith(
        layers: _template.layers.where((l) => l.id != id).toList(),
      ),
    );
    if (_selectedLayerId == id) _selectedLayerId = null;
    _renumberSlots();
  }

  void duplicateSelected() {
    final layer = selectedLayer;
    if (layer == null) return;
    final copy = layer.copyWith(
      id: _uuid.v4(),
      locked: false,
      x: (layer.x + 0.03).clamp(0.0, 0.95),
      y: (layer.y + 0.03).clamp(0.0, 0.95),
      slotIndex: layer.type == TemplateLayerType.photoSlot
          ? _template.slotCount + 1
          : layer.slotIndex,
    );
    addLayer(copy);
  }

  void toggleLock(String id) {
    final layer = _byId(id);
    if (layer == null) return;
    updateLayer(layer.copyWith(locked: !layer.locked));
  }

  void toggleVisible(String id) {
    final layer = _byId(id);
    if (layer == null) return;
    updateLayer(layer.copyWith(visible: !layer.visible));
  }

  /// Move layer in z-order. [delta] +1 = bring forward (later in list).
  void reorderLayer(String id, int delta) {
    final layers = List<TemplateLayer>.from(_template.layers);
    final index = layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= layers.length) return;
    final item = layers.removeAt(index);
    layers.insert(target, item);
    _commit(_template.copyWith(layers: layers));
  }

  void moveLayerToIndex(int from, int to) {
    if (from == to) return;
    final layers = List<TemplateLayer>.from(_template.layers);
    if (from < 0 || from >= layers.length) return;
    final item = layers.removeAt(from);
    final clamped = to.clamp(0, layers.length);
    layers.insert(clamped, item);
    _commit(_template.copyWith(layers: layers));
  }

  TemplateLayer newPhotoSlot({
    double x = 0.1,
    double y = 0.1,
    double w = 0.35,
    double h = 0.35,
  }) {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.photoSlot,
      x: x,
      y: y,
      w: w,
      h: h,
      fit: 'cover',
      slotIndex: _template.slotCount + 1,
    );
  }

  TemplateLayer newText() {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.text,
      x: 0.1,
      y: 0.8,
      w: 0.8,
      h: 0.08,
      text: '{{evento}}',
      role: 'brand',
    );
  }

  TemplateLayer newQr() {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.qr,
      x: 0.35,
      y: 0.35,
      w: 0.3,
      h: 0.3,
      valueKey: 'eventUrl',
    );
  }

  TemplateLayer newShape({String kind = 'rect'}) {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.shape,
      x: 0.2,
      y: 0.2,
      w: 0.4,
      h: 0.2,
      shapeKind: kind,
      fillColor: '#E10600',
      opacity: 1,
    );
  }

  TemplateLayer newImage({String? assetKey, String? role}) {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.image,
      x: 0.35,
      y: 0.05,
      w: 0.3,
      h: 0.12,
      fit: 'contain',
      assetKey: assetKey,
      role: role ?? 'logo',
    );
  }

  TemplateLayer newBackground({String? assetKey, String? fillColor}) {
    return TemplateLayer(
      id: _uuid.v4(),
      type: TemplateLayerType.background,
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      fit: 'contain',
      assetKey: assetKey,
      fillColor: fillColor,
      locked: true,
      role: 'background',
    );
  }

  /// Starter: single full-bleed slot.
  void applyStarterOneSlot() {
    final slot = newPhotoSlot(x: 0.04, y: 0.04, w: 0.92, h: 0.92)
        .copyWith(slotIndex: 1);
    _commit(_template.copyWith(layers: [slot]));
    _selectedLayerId = slot.id;
  }

  /// Starter: vertical strip of 3 slots.
  void applyStarterStrip() {
    const n = 3;
    final slots = <TemplateLayer>[];
    for (var i = 0; i < n; i++) {
      slots.add(
        newPhotoSlot(
          x: 0.08,
          y: 0.04 + i * (0.92 / n),
          w: 0.84,
          h: 0.92 / n - 0.02,
        ).copyWith(slotIndex: i + 1),
      );
    }
    _commit(_template.copyWith(layers: slots));
    _selectedLayerId = slots.first.id;
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_template);
    _template = _undo.removeLast();
    _dirty = true;
    _ensureSelection();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_template);
    _template = _redo.removeLast();
    _dirty = true;
    _ensureSelection();
    notifyListeners();
  }

  void replaceTemplate(PrintTemplate template, {bool asHistory = true}) {
    if (asHistory) {
      _commit(template);
    } else {
      _template = template;
      notifyListeners();
    }
  }

  void _commit(PrintTemplate next) {
    _undo.add(_template);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    _template = next;
    _dirty = true;
    notifyListeners();
  }

  TemplateLayer? _byId(String id) {
    for (final l in _template.layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _ensureSelection() {
    if (_selectedLayerId == null) return;
    if (_byId(_selectedLayerId!) == null) _selectedLayerId = null;
  }

  void _renumberSlots() {
    final slots = _template.orderedPhotoSlots;
    if (slots.isEmpty) return;
    var i = 1;
    final map = {for (final s in slots) s.id: i++};
    final layers = _template.layers.map((l) {
      final idx = map[l.id];
      if (idx == null) return l;
      return l.copyWith(slotIndex: idx);
    }).toList();
    _template = _template.copyWith(layers: layers);
  }

  String nextId() => _uuid.v4();
}
