import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/printing/escpos/thermal_raster.dart';
import 'package:fotoboot_operator/printing/print_crop.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/sample_image.dart';
import 'package:fotoboot_operator/printing/thermal_test_print.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';
import 'package:fotoboot_operator/printing/transport/stub_transport.dart';
import 'package:fotoboot_operator/printing/print_service.dart';
import 'package:fotoboot_operator/printing/epson/epson_print_scaffold.dart';

void main() {
  group('centerCropRect', () {
    test('thermal and epson crops differ for same landscape source', () {
      const w = 1200.0;
      const h = 800.0;
      final thermal = PrinterProfile.byId(PrinterProfileId.thermal80);
      final epson = PrinterProfile.byId(PrinterProfileId.epsonL80504x6);

      final t = centerCropRect(
        sourceWidth: w,
        sourceHeight: h,
        aspectRatio: thermal.aspectRatio,
      );
      final e = centerCropRect(
        sourceWidth: w,
        sourceHeight: h,
        aspectRatio: epson.aspectRatio,
      );

      expect(thermal.aspectRatio, isNot(closeTo(epson.aspectRatio, 0.01)));
      expect(t.width / t.height, closeTo(thermal.aspectRatio, 0.001));
      expect(e.width / e.height, closeTo(epson.aspectRatio, 0.001));
      expect(t.width, isNot(closeTo(e.width, 1)));
    });

    test('normalized crop stays within 0–1', () {
      final n = centerCropNormalized(sourceAspect: 1.5, targetAspect: 0.8);
      expect(n.left, greaterThanOrEqualTo(0));
      expect(n.top, greaterThanOrEqualTo(0));
      expect(n.right, lessThanOrEqualTo(1.001));
      expect(n.bottom, lessThanOrEqualTo(1.001));
    });
  });

  group('ThermalEscPosRasterizer', () {
    test('produces GS v 0 payload with expected width', () {
      final png = buildSamplePng(width: 200, height: 300);
      const rasterizer = ThermalEscPosRasterizer();
      final result = rasterizer.rasterize(
        imageBytes: png,
        profile: PrinterProfile.byId(PrinterProfileId.thermal80),
        dotsWidth: 128,
        dither: ThermalDitherMode.threshold,
      );

      expect(result.widthDots, 128);
      expect(result.bytesPerRow, 16);
      expect(result.bitmap.length, result.bytesPerRow * result.heightDots);
      expect(result.escPosPayload[0], 0x1B);
      expect(result.escPosPayload[1], 0x40);
      // Find GS v 0 header
      expect(result.escPosPayload.contains(0x1D), isTrue);
      final gsIndex = result.escPosPayload.indexOf(0x1D);
      expect(result.escPosPayload[gsIndex + 1], 0x76);
      expect(result.escPosPayload[gsIndex + 2], 0x30);
    });

    test('buildEscPosRaster packs dimensions little-endian', () {
      final bitmap = Uint8List(16 * 10); // 128 dots wide, 10 tall
      final payload = ThermalEscPosRasterizer.buildEscPosRaster(
        widthDots: 128,
        heightDots: 10,
        bitmap: bitmap,
        includeCut: false,
      );
      // After ESC @ (2 bytes): GS v 0 m xL xH yL yH
      expect(payload[2], 0x1D);
      expect(payload[6], 16); // xL bytes per row
      expect(payload[7], 0); // xH
      expect(payload[8], 10); // yL
      expect(payload[9], 0); // yH
    });
  });

  group('ThermalTestPrint + stub transport', () {
    test('test ticket sends bytes successfully on stub', () async {
      final transport = StubPrinterTransport();
      final testPrint = ThermalTestPrint();
      final result = await testPrint.run(
        transport: transport,
        endpoint: PrinterEndpoint.stub,
        profile: PrinterProfile.byId(PrinterProfileId.thermal80),
      );
      expect(result.ok, isTrue);
      expect(transport.sent, isNotEmpty);
      expect(result.bytesSent, greaterThan(0));
    });

    test('surfaces disconnected error', () async {
      final transport = StubPrinterTransport(
        failWith: PrinterException(PrinterErrorCode.disconnected),
      );
      final testPrint = ThermalTestPrint();
      final result = await testPrint.run(
        transport: transport,
        endpoint: PrinterEndpoint.stub,
        profile: PrinterProfile.byId(PrinterProfileId.thermal80),
      );
      expect(result.ok, isFalse);
      expect(result.error, contains('desconectada'));
    });
  });

  group('PrintService', () {
    test('printPhotos sends N rasters', () async {
      final transport = StubPrinterTransport();
      final service = PrintService();
      final png = buildSamplePng(width: 160, height: 200);
      final batch = await service.printPhotos(
        photos: [
          PhotoPrintRequest(imageBytes: png, clientPhotoId: 'a'),
          PhotoPrintRequest(imageBytes: png, clientPhotoId: 'b'),
          PhotoPrintRequest(imageBytes: png, clientPhotoId: 'c'),
        ],
        profile: PrinterProfile.byId(PrinterProfileId.thermal80),
        transport: transport,
        endpoint: PrinterEndpoint.stub,
      );
      expect(batch.allOk, isTrue);
      expect(batch.successCount, 3);
      expect(transport.sent.length, 3);
    });
  });

  group('EpsonPrintScaffold', () {
    test('builds 10x15 jpeg at 300 dpi', () {
      final scaffold = const EpsonPrintScaffold();
      final layout = scaffold.buildPrintLayout(
        imageBytes: buildSamplePng(width: 400, height: 600),
      );
      expect(layout.dpi, 300);
      expect(layout.widthPx, closeTo(1181, 2));
      expect(layout.heightPx, closeTo(1772, 2));
      expect(layout.jpegBytes.length, greaterThan(100));
    });
  });
}
