import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/templates/template_seed.dart';
import 'package:fotoboot_operator/templates/template_validation.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fotoboot_editor_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Mode B createBlank persists empty layers', () async {
    final store = TemplateStore();
    await store.init();
    final created = await store.createBlank(
      paper: const TemplatePaper(
        widthMm: 100,
        heightMm: 150,
        family: PaperFamily.photo,
      ),
      name: 'En blanco',
    );
    expect(created.layers, isEmpty);
    expect(created.paper.label, '10×15 cm');
    expect(store.getById(created.id)!.name, 'En blanco');
  });

  test('Mode A createWithBackground stores asset + locked bg layer', () async {
    final store = TemplateStore();
    await store.init();
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // minimal header bytes
    ]);
    // Store accepts any bytes; decoding happens in UI/composer.
    final created = await store.createWithBackground(
      paper: TemplateSeed.thermalPaper,
      name: 'Fondo Canva',
      backgroundBytes: png,
    );
    expect(created.layers.length, 1);
    expect(created.layers.first.type, TemplateLayerType.background);
    expect(created.layers.first.locked, isTrue);
    expect(created.layers.first.assetKey, isNotNull);
    final assets = await store.loadAssetsFor(created);
    expect(assets.containsKey(created.layers.first.assetKey), isTrue);
  });

  test('editor controller undo/redo and slot starter', () {
    final base = PrintTemplate(
      id: 't1',
      name: 'Demo',
      paper: TemplateSeed.thermalPaper,
      layers: const [],
    );
    final c = TemplateEditorController(initial: base);
    c.applyStarterOneSlot();
    expect(c.template.slotCount, 1);
    expect(c.template.layers.first.slotIndex, 1);
    c.applyStarterStrip();
    expect(c.template.slotCount, 3);
    c.undo();
    expect(c.template.slotCount, 1);
    c.redo();
    expect(c.template.slotCount, 3);

    final slot = c.newPhotoSlot();
    c.addLayer(slot);
    expect(c.template.slotCount, 4);
    c.selectLayer(slot.id);
    c.removeSelected();
    expect(c.template.slotCount, 3);
  });

  test('validation blocks activate with duplicate slot indices', () {
    final template = PrintTemplate(
      id: 'bad',
      name: 'Bad',
      paper: TemplateSeed.thermalPaper,
      layers: const [
        TemplateLayer(
          id: 'a',
          type: TemplateLayerType.photoSlot,
          x: 0.1,
          y: 0.1,
          w: 0.3,
          h: 0.3,
          fit: 'cover',
          slotIndex: 1,
        ),
        TemplateLayer(
          id: 'b',
          type: TemplateLayerType.photoSlot,
          x: 0.5,
          y: 0.1,
          w: 0.3,
          h: 0.3,
          fit: 'cover',
          slotIndex: 1,
        ),
      ],
    );
    expect(TemplateValidation.canActivate(template), isFalse);
    expect(
      TemplateValidation.activateIssues(template)
          .any((i) => i.message.contains('duplicados')),
      isTrue,
    );
  });

  test('JSON round-trip keeps Corte B fields', () {
    final layer = TemplateLayer(
      id: 'bg',
      type: TemplateLayerType.background,
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      fit: 'contain',
      assetKey: 'asset-1',
      locked: true,
      opacity: 0.9,
      cornerRadius: 0.05,
      fillColor: '#FFFFFF',
    );
    final original = PrintTemplate(
      id: 'x',
      name: 'Con fondo',
      paper: TemplateSeed.thermalPaper,
      layers: [
        layer,
        const TemplateLayer(
          id: 's',
          type: TemplateLayerType.photoSlot,
          x: 0.1,
          y: 0.1,
          w: 0.4,
          h: 0.4,
          fit: 'contain',
          slotIndex: 1,
        ),
        const TemplateLayer(
          id: 'shape',
          type: TemplateLayerType.shape,
          x: 0.2,
          y: 0.6,
          w: 0.3,
          h: 0.2,
          shapeKind: 'circle',
          fillColor: '#E10600',
        ),
      ],
      dpi: 203,
    );
    final restored = PrintTemplate.fromMap(original.toMap());
    expect(restored.dpi, 203);
    expect(restored.layers[0].type, TemplateLayerType.background);
    expect(restored.layers[0].assetKey, 'asset-1');
    expect(restored.layers[1].slotIndex, 1);
    expect(restored.layers[1].fit, 'contain');
    expect(restored.layers[2].shapeKind, 'circle');
    expect(restored.toMap(), original.toMap());
  });
}
