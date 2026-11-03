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
    const paperRect = Rect.fromLTWH(0, 0, 400, 50);
    final style = resolveTextStyle(layer, paper, paperRect, paperRect);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.textAlign, TextAlign.center);
    expect(style.maxLines, 2);
    expect(style.fontSize, closeTo(27.5, 0.1)); // 0.55 * 50
  });

  test('14pt on 576px/80mm canvas is ~35.6px independent of layer height', () {
    const paper = TemplateSeed.thermalPaper;
    const paperRect = Rect.fromLTWH(0, 0, 576, 720);
    const base = TemplateLayer(
      id: 't',
      type: TemplateLayerType.text,
      x: 0.1,
      y: 0.1,
      w: 0.8,
      h: 0.08,
      text: 'Title',
      fontSizePt: 14,
      fontWeight: 'bold',
    );
    final shortBox = Rect.fromLTWH(57.6, 72, 460.8, 57.6);
    final tallBox = Rect.fromLTWH(57.6, 72, 460.8, 360);
    final shortStyle = resolveTextStyle(base, paper, shortBox, paperRect);
    final tallStyle = resolveTextStyle(
      base.copyWith(h: 0.5),
      paper,
      tallBox,
      paperRect,
    );
    expect(shortStyle.fontSize, closeTo(35.6, 0.2));
    expect(tallStyle.fontSize, closeTo(35.6, 0.2));
    expect(shortStyle.fontSize, tallStyle.fontSize);
  });

  test('strokeWidthPxFromMm on 576px/80mm thermal is ~2.5px for 0.35mm', () {
    const paper = TemplateSeed.thermalPaper;
    const paperRect = Rect.fromLTWH(0, 0, 576, 720);
    expect(
      strokeWidthPxFromMm(0.35, paper, paperRect),
      closeTo(2.52, 0.05),
    );
  });

  test('unset maxLines uses TemplateTextDefaults in renderer', () {
    const layer = TemplateLayer(
      id: 't',
      type: TemplateLayerType.text,
      x: 0,
      y: 0,
      w: 1,
      h: 0.1,
      text: 'X',
      fontSizePt: 10,
    );
    const paper = TemplateSeed.thermalPaper;
    const paperRect = Rect.fromLTWH(0, 0, 576, 720);
    const layerRect = Rect.fromLTWH(0, 0, 576, 72);
    final style = resolveTextStyle(layer, paper, layerRect, paperRect);
    expect(style.maxLines, TemplateTextDefaults.defaultMaxLines);
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
