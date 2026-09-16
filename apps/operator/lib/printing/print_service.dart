import 'dart:typed_data';

import 'package:fotoboot_operator/printing/escpos/thermal_raster.dart';
import 'package:fotoboot_operator/printing/epson/epson_print_scaffold.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';

class PhotoPrintRequest {
  const PhotoPrintRequest({
    required this.imageBytes,
    this.photoId,
    this.clientPhotoId,
  });

  final Uint8List imageBytes;

  /// Server id when synced (Phase C); optional for local-only prints.
  final String? photoId;
  final String? clientPhotoId;
}

class PhotoPrintItemResult {
  const PhotoPrintItemResult({
    required this.ok,
    this.photoId,
    this.clientPhotoId,
    this.error,
    this.bytesSent = 0,
  });

  final bool ok;
  final String? photoId;
  final String? clientPhotoId;
  final String? error;
  final int bytesSent;
}

class BatchPrintResult {
  const BatchPrintResult({required this.items});

  final List<PhotoPrintItemResult> items;

  bool get allOk => items.every((i) => i.ok);
  int get successCount => items.where((i) => i.ok).length;
  int get failCount => items.length - successCount;
}

/// App-layer print API: 1 photo or N photos for the active profile.
///
/// Galería/Detalle compose pages via [TemplatePrintFlow] then call
/// [printPhotos] / [printOne] with the rendered template PNGs.
class PrintService {
  PrintService({
    ThermalEscPosRasterizer? rasterizer,
    EpsonPrintScaffold? epson,
  })  : _rasterizer = rasterizer ?? const ThermalEscPosRasterizer(),
        _epson = epson ?? const EpsonPrintScaffold();

  final ThermalEscPosRasterizer _rasterizer;
  final EpsonPrintScaffold _epson;

  Future<PhotoPrintItemResult> printOne({
    required PhotoPrintRequest photo,
    required PrinterProfile profile,
    required PrinterTransport transport,
    required PrinterEndpoint endpoint,
    int copies = 1,
  }) async {
    final batch = await printPhotos(
      photos: [photo],
      profile: profile,
      transport: transport,
      endpoint: endpoint,
      copies: copies,
    );
    return batch.items.first;
  }

  Future<BatchPrintResult> printPhotos({
    required List<PhotoPrintRequest> photos,
    required PrinterProfile profile,
    required PrinterTransport transport,
    required PrinterEndpoint endpoint,
    int copies = 1,
  }) async {
    if (photos.isEmpty) {
      return const BatchPrintResult(items: []);
    }

    final results = <PhotoPrintItemResult>[];

    try {
      await transport.connect(endpoint);
    } on PrinterException catch (e) {
      return BatchPrintResult(
        items: photos
            .map(
              (p) => PhotoPrintItemResult(
                ok: false,
                photoId: p.photoId,
                clientPhotoId: p.clientPhotoId,
                error: e.messageEs,
              ),
            )
            .toList(),
      );
    }

    for (final photo in photos) {
      try {
        if (profile.kind == PrinterKind.thermal) {
          final raster = _rasterizer.rasterize(
            imageBytes: photo.imageBytes,
            profile: profile,
          );
          for (var c = 0; c < copies; c++) {
            await transport.send(raster.escPosPayload);
          }
          results.add(
            PhotoPrintItemResult(
              ok: true,
              photoId: photo.photoId,
              clientPhotoId: photo.clientPhotoId,
              bytesSent: raster.escPosPayload.length * copies,
            ),
          );
        } else {
          // D5 scaffold — generate layout bytes; send path is TODO.
          final layout = _epson.buildPrintLayout(
            imageBytes: photo.imageBytes,
            profile: profile,
          );
          await _epson.sendToPrinter(
            layout: layout,
            transport: transport,
          );
          results.add(
            PhotoPrintItemResult(
              ok: true,
              photoId: photo.photoId,
              clientPhotoId: photo.clientPhotoId,
              bytesSent: layout.jpegBytes.length * copies,
            ),
          );
        }
      } on PrinterException catch (e) {
        results.add(
          PhotoPrintItemResult(
            ok: false,
            photoId: photo.photoId,
            clientPhotoId: photo.clientPhotoId,
            error: e.messageEs,
          ),
        );
      } catch (e) {
        results.add(
          PhotoPrintItemResult(
            ok: false,
            photoId: photo.photoId,
            clientPhotoId: photo.clientPhotoId,
            error: e.toString(),
          ),
        );
      }
    }

    return BatchPrintResult(items: results);
  }
}
