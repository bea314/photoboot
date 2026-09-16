import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:fotoboot_operator/models/print_template.dart';
import 'package:fotoboot_operator/printing/print_job_reporter.dart';
import 'package:fotoboot_operator/printing/print_service.dart';
import 'package:fotoboot_operator/printing/printer_profiles.dart';
import 'package:fotoboot_operator/printing/printer_settings.dart';
import 'package:fotoboot_operator/printing/transport/bluetooth_transport.dart';
import 'package:fotoboot_operator/printing/transport/printer_transport.dart';
import 'package:fotoboot_operator/printing/transport/stub_transport.dart';
import 'package:fotoboot_operator/printing/transport/tcp_transport.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/template_store.dart';
import 'package:fotoboot_operator/templates/template_composer.dart';
import 'package:fotoboot_operator/templates/template_paging.dart';
import 'package:fotoboot_operator/templates/template_tokens.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

PaperFamily paperFamilyForProfile(PrinterProfile profile) {
  return profile.kind == PrinterKind.thermal
      ? PaperFamily.thermal
      : PaperFamily.photo;
}

PrinterTransport transportForEndpoint(PrinterEndpoint endpoint) {
  switch (endpoint.transportId) {
    case 'tcp':
      return TcpPrinterTransport();
    case 'bluetooth':
      return BluetoothPrinterTransport();
    default:
      return StubPrinterTransport();
  }
}

/// Shared Galería / Detalle print path with active template (T3).
class TemplatePrintFlow {
  TemplatePrintFlow({
    PrinterSettingsStore? settings,
    TemplateStore? templates,
    PrintService? printService,
    TemplateComposer? composer,
  })  : _settings = settings ?? PrinterSettingsStore(),
        _templates = templates ?? TemplateStore(),
        _printService = printService ?? PrintService(),
        _composer = composer ?? const TemplateComposer();

  final PrinterSettingsStore _settings;
  final TemplateStore _templates;
  final PrintService _printService;
  final TemplateComposer _composer;

  /// Returns `true` if at least one page printed successfully.
  Future<bool> printPhotoBatch({
    required BuildContext context,
    required PhotoController photos,
    required ApiClient api,
    required List<LocalPhoto> batch,
  }) async {
    if (batch.isEmpty) return false;

    await _templates.init();

    final warning = await _settings.galleryPrintWarning();
    if (warning != null && context.mounted) {
      final proceed = await _showTestFailWarning(context, warning);
      if (proceed != true) return false;
    }

    final profileId = await _settings.readActiveProfileId();
    final profile = PrinterProfile.byId(profileId);
    final family = paperFamilyForProfile(profile);
    final template = _templates.activeFor(family);

    if (!templateAcceptsPhotoBatch(template)) {
      if (context.mounted) {
        await _showChooseTemplateSheet(context);
      }
      return false;
    }

    final pages = chunkPhotosForSlots(batch, template!.slotCount);
    final pageCount = pages.length;

    EventInfo? event;
    try {
      event = await api.getCurrentEvent();
    } catch (_) {
      event = null;
    }
    final printContext = TemplatePrintContext.fromEvent(
      eventName: event?.name ?? 'Fotoboot',
      eventUrl: event?.publicUrl,
    );

    final firstPhotoBytes =
        await photos.files.readBest(batch.first.clientPhotoId);
    if (!context.mounted) return false;
    final confirmed = await _confirmPrint(
      context: context,
      template: template,
      profile: profile,
      photoCount: batch.length,
      pageCount: pageCount,
      printContext: printContext,
      firstPhotoBytes: firstPhotoBytes,
    );
    if (confirmed != true) return false;

    final endpoint =
        await _settings.readLastEndpoint() ?? PrinterEndpoint.stub;
    final transport = transportForEndpoint(endpoint);
    final reporter = PrintJobReporter(api: api);

    final composedRequests = <PhotoPrintRequest>[];
    final pagePhotoIds = <List<LocalPhoto>>[];

    for (final pagePhotos in pages) {
      final slotBytes = <Uint8List>[];
      for (final photo in pagePhotos) {
        final bytes = await photos.files.readOriginal(photo.clientPhotoId) ??
            await photos.files.readBest(photo.clientPhotoId);
        if (bytes == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No hay archivo local para ${photo.clientPhotoId.substring(0, 8)}',
                ),
              ),
            );
          }
          return false;
        }
        slotBytes.add(bytes);
      }

      final pagePng = await _composer.composePng(
        template: template,
        context: printContext,
        photoBytes: slotBytes,
        widthPx: profile.thermalDotsWidth ?? 576,
      );
      composedRequests.add(
        PhotoPrintRequest(
          imageBytes: pagePng,
          photoId: pagePhotos.first.serverId,
          clientPhotoId: pagePhotos.first.clientPhotoId,
        ),
      );
      pagePhotoIds.add(pagePhotos);
    }

    final result = await _printService.printPhotos(
      photos: composedRequests,
      profile: profile,
      transport: transport,
      endpoint: endpoint,
    );
    await transport.disconnect();

    var anyOk = false;
    for (var i = 0; i < result.items.length; i++) {
      final item = result.items[i];
      final pagePhotos = pagePhotoIds[i];
      if (item.ok) {
        anyOk = true;
        for (final photo in pagePhotos) {
          await photos.markPrintedLocally(photo.clientPhotoId);
        }
      }
      final serverIds =
          pagePhotos.map((p) => p.serverId).whereType<String>().toList();
      if (serverIds.isNotEmpty) {
        await reporter.report(
          PrintJobReport(
            eventId: pagePhotos.first.eventId,
            printerProfile: profile.id.apiId,
            copies: 1,
            localStatus: item.ok ? 'printed' : 'failed',
            type: 'photo',
            photoIds: serverIds,
            error: item.error,
          ),
        );
      }
    }

    if (context.mounted) {
      final msg = result.allOk
          ? (pageCount == 1
              ? 'Impresa con “${template.name}”'
              : '$pageCount páginas impresas (“${template.name}”)')
          : (result.items.firstWhere((i) => !i.ok, orElse: () => result.items.first)
                  .error ??
              'Error al imprimir');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: result.allOk ? null : AppColors.redDark,
        ),
      );
    }
    return anyOk;
  }

  Future<bool?> _showTestFailWarning(BuildContext context, String warning) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Impresora'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                warning,
                style: const TextStyle(
                  color: AppColors.redDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                  context.go('/templates/printer');
                },
                icon: const Icon(Icons.settings_suggest_outlined),
                label: const Text('Ir a Avanzado'),
                style: TextButton.styleFrom(foregroundColor: AppColors.redDark),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Imprimir igual'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChooseTemplateSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Elige una plantilla para imprimir',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No hay una plantilla activa con huecos para fotos '
                  'en esta familia de papel. El Ticket QR no consume fotos: '
                  'elige Ticket foto (u otra con photoSlot) en Gestión.',
                  style: TextStyle(color: AppColors.grey, height: 1.35),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.go('/templates');
                  },
                  child: const Text('Ir a Gestión'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmPrint({
    required BuildContext context,
    required PrintTemplate template,
    required PrinterProfile profile,
    required int photoCount,
    required int pageCount,
    required TemplatePrintContext printContext,
    Uint8List? firstPhotoBytes,
  }) async {
    ui.Image? previewPhoto;
    if (firstPhotoBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(firstPhotoBytes);
        final frame = await codec.getNextFrame();
        previewPhoto = frame.image;
      } catch (_) {
        previewPhoto = null;
      }
    }

    if (!context.mounted) {
      previewPhoto?.dispose();
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar impresión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${profile.label} · ${template.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  photoCount == 1
                      ? '1 foto · $pageCount página'
                      : '$photoCount fotos · $pageCount '
                          '${pageCount == 1 ? 'página' : 'páginas'}',
                  style: const TextStyle(color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                TemplatePrintPreview(
                  template: template,
                  contextData: printContext,
                  photos: [previewPhoto],
                  height: 200,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(pageCount > 1 ? 'Imprimir $pageCount' : 'Imprimir'),
            ),
          ],
        );
      },
    );
    previewPhoto?.dispose();
    return result;
  }
}
