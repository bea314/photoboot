import 'dart:typed_data';

import 'package:fotoboot_operator/printing/escpos/thermal_raster.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/sample_image.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

class TestPrintResult {
  const TestPrintResult({
    required this.ok,
    this.error,
    this.bytesSent = 0,
  });

  final bool ok;
  final String? error;
  final int bytesSent;
}

/// Builds and sends the thermal “Imprimir prueba” ticket.
class ThermalTestPrint {
  ThermalTestPrint({
    ThermalEscPosRasterizer? rasterizer,
  }) : _rasterizer = rasterizer ?? const ThermalEscPosRasterizer();

  final ThermalEscPosRasterizer _rasterizer;

  /// Compose header text + contrast ramp + sample photo into one ESC/POS stream.
  Uint8List buildTicketBytes({
    required PrinterProfile profile,
    String? deviceLabel,
    DateTime? now,
    Uint8List? sampleImageBytes,
  }) {
    final when = now ?? DateTime.now();
    final stamp =
        '${when.year.toString().padLeft(4, '0')}-'
        '${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';

    final header = ThermalEscPosRasterizer.buildTextLines(
      [
        'FOTOBOOT',
        'Test print OK?',
        'Perfil: ${profile.id.apiId}',
        'Marco: ${profile.frameLabel}',
        if (deviceLabel != null && deviceLabel.isNotEmpty) 'Disp: $deviceLabel',
        'Fecha: $stamp',
        '----------------',
      ],
      bold: true,
    );

    final contrast = _rasterizer.rasterize(
      imageBytes: buildContrastBlockPng(),
      profile: profile,
      dotsWidth: profile.thermalDotsWidth ?? 576,
      dither: ThermalDitherMode.threshold,
      includeCut: false,
    );

    final sample = _rasterizer.rasterize(
      imageBytes: sampleImageBytes ?? buildSamplePng(),
      profile: profile,
      dither: ThermalDitherMode.floydSteinberg,
      includeCut: true,
    );

    final out = BytesBuilder(copy: false);
    out.add(header);
    // Skip ESC @ on subsequent payloads — strip leading init from raster chunks.
    out.add(_stripInit(contrast.escPosPayload));
    out.add(
      ThermalEscPosRasterizer.buildTextLines(['', 'Sample crop:', '']),
    );
    out.add(_stripInit(sample.escPosPayload));
    out.add(ThermalEscPosRasterizer.buildTextLines(['Fotoboot OK', '']));
    return out.toBytes();
  }

  Future<TestPrintResult> run({
    required PrinterTransport transport,
    required PrinterEndpoint endpoint,
    required PrinterProfile profile,
    Uint8List? sampleImageBytes,
  }) async {
    try {
      await transport.connect(endpoint);
      final bytes = buildTicketBytes(
        profile: profile,
        deviceLabel: endpoint.displayName,
        sampleImageBytes: sampleImageBytes,
      );
      await transport.send(bytes);
      return TestPrintResult(ok: true, bytesSent: bytes.length);
    } on PrinterException catch (e) {
      return TestPrintResult(ok: false, error: e.messageEs);
    } catch (e) {
      return TestPrintResult(ok: false, error: e.toString());
    }
  }

  static Uint8List _stripInit(Uint8List payload) {
    if (payload.length >= 2 && payload[0] == 0x1B && payload[1] == 0x40) {
      return payload.sublist(2);
    }
    return payload;
  }
}
