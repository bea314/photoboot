import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/printing/sample_image.dart';
import 'package:fotoboot_operator/templates/template_composer.dart';
import 'package:fotoboot_operator/templates/template_paging.dart';
import 'package:fotoboot_operator/templates/template_seed.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplatePrintContext tokens', () {
    test('resolves evento fecha hora and eventUrl', () {
      final ctx = TemplatePrintContext.fromEvent(
        eventName: 'Boda Ana',
        eventUrl: 'https://example.com/e/boda',
        at: DateTime(2026, 9, 16, 15, 4),
      );
      expect(ctx.evento, 'Boda Ana');
      expect(ctx.fecha, '16/09/2026');
      expect(ctx.hora, '15:04');
      expect(
        ctx.resolve('{{evento}} · {{fecha}} · {{hora}}'),
        'Boda Ana · 16/09/2026 · 15:04',
      );
      expect(ctx.resolve('Link {{eventUrl}}'), 'Link https://example.com/e/boda');
      expect(ctx.qrPayload, 'https://example.com/e/boda');
    });
  });

  group('template paging', () {
    test('ceil(N/S) for photo templates', () {
      expect(templatePageCount(photoCount: 1, slotCount: 1), 1);
      expect(templatePageCount(photoCount: 3, slotCount: 1), 3);
      expect(templatePageCount(photoCount: 5, slotCount: 2), 3);
      expect(templatePageCount(photoCount: 4, slotCount: 2), 2);
    });

    test('ticket QR (0 slots) does not consume photos', () {
      expect(templatePageCount(photoCount: 5, slotCount: 0), 0);
      expect(pageCountForTemplate(TemplateSeed.ticketQr(), 5), 0);
      expect(templateAcceptsPhotoBatch(TemplateSeed.ticketQr()), isFalse);
      expect(templateAcceptsPhotoBatch(TemplateSeed.ticketFoto()), isTrue);
      expect(chunkPhotosForSlots(['a', 'b', 'c'], 0), isEmpty);
    });

    test('chunks photos into pages', () {
      final pages = chunkPhotosForSlots([1, 2, 3, 4, 5], 2);
      expect(pages, [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });
  });

  group('coverCropForSlot', () {
    test('matches slot aspect, not full paper', () {
      // Landscape photo into a tall slot (ticket foto ~0.88/0.58).
      final crop = coverCropForSlot(
        sourceWidth: 1200,
        sourceHeight: 800,
        slotW: 0.88,
        slotH: 0.58,
      );
      expect(crop.width / crop.height, closeTo(0.88 / 0.58, 0.001));
    });
  });

  group('TemplateComposer', () {
    test('ticket foto page includes photo slot cover render', () async {
      final png = buildSamplePng(width: 400, height: 300);
      final bytes = await const TemplateComposer().composePng(
        template: TemplateSeed.ticketFoto(),
        context: TemplatePrintContext.fromEvent(
          eventName: 'Demo',
          eventUrl: 'https://fotoboot.test/e/demo',
          at: DateTime(2026, 1, 2, 10, 30),
        ),
        photoBytes: [png],
        widthPx: 240,
      );
      expect(bytes.length, greaterThan(200));
      // PNG magic
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
    });

    test('ticket QR renders without photos', () async {
      final bytes = await const TemplateComposer().composePng(
        template: TemplateSeed.ticketQr(),
        context: const TemplatePrintContext(
          evento: 'Demo',
          fecha: '01/01/2026',
          hora: '12:00',
          eventUrl: 'https://fotoboot.test/e/demo',
        ),
        photoBytes: const [],
        widthPx: 200,
      );
      expect(bytes.length, greaterThan(200));
    });
  });

  group('seed slot counts', () {
    test('ticket foto has 1 slot; QR has 0', () {
      expect(TemplateSeed.ticketFoto().slotCount, 1);
      expect(TemplateSeed.ticketQr().slotCount, 0);
      expect(
        TemplateSeed.ticketFoto()
            .layers
            .where((l) => l.type == TemplateLayerType.photoSlot)
            .first
            .fit,
        'cover',
      );
    });
  });
}
