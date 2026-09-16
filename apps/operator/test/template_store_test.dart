import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/template_seed.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fotoboot_templates_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('seed inserts ticket QR + ticket foto; thermal active is ticket foto',
      () async {
    final store = TemplateStore();
    await store.init();

    final all = store.listAll();
    expect(all.length, 2);

    final qr = store.getById(TemplateSeed.ticketQrId)!;
    final foto = store.getById(TemplateSeed.ticketFotoId)!;

    expect(qr.name, 'Ticket QR');
    expect(qr.slotCount, 0);
    expect(
      qr.layers.any((l) => l.type == TemplateLayerType.qr),
      isTrue,
    );
    expect(
      qr.layers.any((l) => l.type == TemplateLayerType.photoSlot),
      isFalse,
    );

    expect(foto.name, 'Ticket foto');
    expect(foto.slotCount, 1);
    final slot =
        foto.layers.firstWhere((l) => l.type == TemplateLayerType.photoSlot);
    expect(slot.fit, 'cover');
    expect(
      foto.layers.any((l) => l.text?.contains('{{fecha}}') == true),
      isTrue,
    );
    expect(
      foto.layers.any((l) => l.text?.contains('{{hora}}') == true),
      isTrue,
    );

    expect(foto.isActive, isTrue);
    expect(qr.isActive, isFalse);
    expect(store.activeIdFor(PaperFamily.thermal), TemplateSeed.ticketFotoId);
    expect(store.activeIdFor(PaperFamily.photo), isNull);
  });

  test('setActive switches thermal family only', () async {
    final store = TemplateStore();
    await store.init();

    await store.setActive(TemplateSeed.ticketQrId);
    expect(store.getById(TemplateSeed.ticketQrId)!.isActive, isTrue);
    expect(store.getById(TemplateSeed.ticketFotoId)!.isActive, isFalse);

    // Photo family still unset.
    expect(store.activeIdFor(PaperFamily.photo), isNull);
  });

  test('duplicate and createGeneric persist', () async {
    final store = TemplateStore();
    await store.init();

    final copy = await store.duplicate(TemplateSeed.ticketQrId);
    expect(copy.name, 'Ticket QR (copia)');
    expect(copy.isActive, isFalse);
    expect(store.listAll().length, 3);

    final created = await store.createGeneric(
      paper: const TemplatePaper(
        widthMm: 100,
        heightMm: 150,
        family: PaperFamily.photo,
      ),
      name: 'Plantilla 10×15',
    );
    expect(created.paper.label, '10×15 cm');
    expect(created.paper.family, PaperFamily.photo);
    expect(created.slotCount, 1);
    expect(store.listAll().length, 4);

    final thermalNew = await store.createGeneric(
      paper: TemplateSeed.thermalPaper,
    );
    expect(thermalNew.slotCount, 1);
    expect(
      thermalNew.layers.any((l) => l.type == TemplateLayerType.photoSlot),
      isTrue,
    );
  });

  test('JSON round-trip preserves layers', () {
    final original = TemplateSeed.ticketFoto();
    final restored = PrintTemplate.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.layers.length, original.layers.length);
    expect(restored.layers.first.type, TemplateLayerType.photoSlot);
    expect(restored.toMap(), original.toMap());
  });

  test('ensureSeeded is idempotent', () async {
    final store = TemplateStore();
    await store.init();
    await store.setActive(TemplateSeed.ticketQrId);
    await store.init();
    expect(store.listAll().length, 2);
    expect(store.activeIdFor(PaperFamily.thermal), TemplateSeed.ticketQrId);
  });
}
