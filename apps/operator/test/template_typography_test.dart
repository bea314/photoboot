import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/templates/editor/template_editor_controller.dart';
import 'package:fotoboot_operator/templates/template_layer_typography.dart';
import 'package:fotoboot_operator/templates/template_seed.dart';

void main() {
  test('legacy text style matches Corte B defaults when fields absent', () {
    const layer = TemplateLayer(
      id: 't',
      type: TemplateLayerType.text,
      x: 0.1,
      y: 0.2,
      w: 0.8,
      h: 0.1,
      text: 'Hola',
    );
    const paper = TemplateSeed.thermalPaper;
    const rect = Rect.fromLTWH(0, 0, 400, 50);
    final style = resolveTextStyle(layer, paper, rect);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.textAlign, TextAlign.center);
    expect(style.maxLines, 2);
    expect(style.fontSize, closeTo(27.5, 0.1)); // 0.55 * 50
  });

  test('fontSizePt scales with paper mm not screen px', () {
    const layer = TemplateLayer(
      id: 't',
      type: TemplateLayerType.text,
      x: 0,
      y: 0,
      w: 1,
      h: 0.1,
      text: 'Hola',
      fontSizePt: 12,
    );
    const paper = TemplateSeed.thermalPaper;
    const rectSmall = Rect.fromLTWH(0, 0, 200, 20);
    const rectLarge = Rect.fromLTWH(0, 0, 600, 60);
    final small = resolveTextStyle(layer, paper, rectSmall).fontSize;
    final large = resolveTextStyle(layer, paper, rectLarge).fontSize;
    expect(large / small, closeTo(3, 0.01));
  });

  test('JSON round-trip keeps Corte C typography and shape stroke', () {
    const layer = TemplateLayer(
      id: 'txt',
      type: TemplateLayerType.text,
      x: 0.1,
      y: 0.1,
      w: 0.8,
      h: 0.1,
      text: '{{evento}}',
      fontSizePt: 14,
      fontWeight: 'bold',
      fontFamily: 'Montserrat',
      textAlign: 'left',
      color: '#E10600',
      maxLines: 3,
    );
    final map = layer.toMap();
    final restored = TemplateLayer.fromMap(map);
    expect(restored.fontSizePt, 14);
    expect(restored.fontWeight, 'bold');
    expect(restored.fontFamily, 'Montserrat');
    expect(restored.textAlign, 'left');
    expect(restored.color, '#E10600');
    expect(restored.maxLines, 3);
    expect(restored.toMap(), map);
  });

  test('starters replace only photoSlots', () {
    const bg = TemplateLayer(
      id: 'bg',
      type: TemplateLayerType.background,
      x: 0,
      y: 0,
      w: 1,
      h: 1,
      fillColor: '#FFFFFF',
    );
    const text = TemplateLayer(
      id: 'brand',
      type: TemplateLayerType.text,
      x: 0.1,
      y: 0.8,
      w: 0.8,
      h: 0.08,
      text: '{{evento}}',
    );
    final base = PrintTemplate(
      id: 't1',
      name: 'Demo',
      paper: TemplateSeed.thermalPaper,
      layers: const [bg, text],
    );
    final c = TemplateEditorController(initial: base);
    c.applyStarterStrip();
    expect(c.template.slotCount, 3);
    expect(
      c.template.layers.where((l) => l.type == TemplateLayerType.background),
      isNotEmpty,
    );
    expect(
      c.template.layers.where((l) => l.type == TemplateLayerType.text),
      isNotEmpty,
    );
  });

  test('text presets apply expected defaults', () {
    const layer = TemplateLayer(
      id: 't',
      type: TemplateLayerType.text,
      x: 0,
      y: 0,
      w: 1,
      h: 0.1,
      text: 'X',
    );
    final title = TemplateTextPresets.apply(layer, TemplateTextPresetId.title);
    expect(title.fontSizePt, 14);
    expect(title.fontWeight, 'bold');
  });
}
