import 'package:fotoboot_operator/models/print_template.dart';

/// Built-in thermal 80 mm seeds (T2). No 10×15 color seed yet.
abstract final class TemplateSeed {
  static const ticketQrId = 'seed-ticket-qr';
  static const ticketFotoId = 'seed-ticket-foto';

  static const thermalPaper = TemplatePaper(
    widthMm: 80,
    heightMm: 100,
    family: PaperFamily.thermal,
  );

  /// Ticket QR: logo + CTA + event QR + URL. **No photoSlot.**
  static PrintTemplate ticketQr() {
    return const PrintTemplate(
      id: ticketQrId,
      name: 'Ticket QR',
      paper: thermalPaper,
      layers: [
        TemplateLayer(
          id: 'logo',
          type: TemplateLayerType.image,
          x: 0.18,
          y: 0.06,
          w: 0.64,
          h: 0.12,
          role: 'logo',
        ),
        TemplateLayer(
          id: 'cta',
          type: TemplateLayerType.text,
          x: 0.08,
          y: 0.22,
          w: 0.84,
          h: 0.1,
          text: 'Escanea y descarga tus fotos',
          role: 'cta',
        ),
        TemplateLayer(
          id: 'qr',
          type: TemplateLayerType.qr,
          x: 0.2,
          y: 0.36,
          w: 0.6,
          h: 0.42,
          valueKey: 'eventUrl',
        ),
        TemplateLayer(
          id: 'url',
          type: TemplateLayerType.text,
          x: 0.08,
          y: 0.84,
          w: 0.84,
          h: 0.08,
          text: '{{eventUrl}}',
          role: 'url',
        ),
      ],
    );
  }

  /// Ticket foto: photoSlot cover + brand text + {{fecha}}/{{hora}} + logo.
  static PrintTemplate ticketFoto() {
    return const PrintTemplate(
      id: ticketFotoId,
      name: 'Ticket foto',
      paper: thermalPaper,
      layers: [
        TemplateLayer(
          id: 'slot',
          type: TemplateLayerType.photoSlot,
          x: 0.06,
          y: 0.05,
          w: 0.88,
          h: 0.58,
          fit: 'cover',
        ),
        TemplateLayer(
          id: 'brand',
          type: TemplateLayerType.text,
          x: 0.08,
          y: 0.66,
          w: 0.84,
          h: 0.08,
          text: '{{evento}}',
          role: 'brand',
        ),
        TemplateLayer(
          id: 'timestamp',
          type: TemplateLayerType.text,
          x: 0.08,
          y: 0.75,
          w: 0.84,
          h: 0.06,
          text: '{{fecha}} · {{hora}}',
          role: 'timestamp',
        ),
        TemplateLayer(
          id: 'logo',
          type: TemplateLayerType.image,
          x: 0.35,
          y: 0.84,
          w: 0.3,
          h: 0.1,
          role: 'logo',
        ),
      ],
    );
  }

  static List<PrintTemplate> all() => [ticketQr(), ticketFoto()];

  /// Default active thermal template (has photoSlot for Galería/Detalle print).
  static String get defaultActiveThermalId => ticketFotoId;

  /// Generic 1-slot layout for "Nueva plantilla".
  /// Thermal → ticket-foto style; photo family → full-bleed slot.
  static PrintTemplate genericOneSlot({
    required String id,
    required String name,
    required TemplatePaper paper,
  }) {
    if (paper.family == PaperFamily.thermal) {
      return PrintTemplate(
        id: id,
        name: name,
        paper: paper,
        layers: const [
          TemplateLayer(
            id: 'slot',
            type: TemplateLayerType.photoSlot,
            x: 0.06,
            y: 0.05,
            w: 0.88,
            h: 0.58,
            fit: 'cover',
          ),
          TemplateLayer(
            id: 'brand',
            type: TemplateLayerType.text,
            x: 0.08,
            y: 0.66,
            w: 0.84,
            h: 0.08,
            text: '{{evento}}',
            role: 'brand',
          ),
          TemplateLayer(
            id: 'timestamp',
            type: TemplateLayerType.text,
            x: 0.08,
            y: 0.75,
            w: 0.84,
            h: 0.06,
            text: '{{fecha}} · {{hora}}',
            role: 'timestamp',
          ),
          TemplateLayer(
            id: 'logo',
            type: TemplateLayerType.image,
            x: 0.35,
            y: 0.84,
            w: 0.3,
            h: 0.1,
            role: 'logo',
          ),
        ],
      );
    }

    return PrintTemplate(
      id: id,
      name: name,
      paper: paper,
      layers: const [
        TemplateLayer(
          id: 'slot',
          type: TemplateLayerType.photoSlot,
          x: 0.04,
          y: 0.04,
          w: 0.92,
          h: 0.92,
          fit: 'cover',
        ),
      ],
    );
  }

  static TemplatePaper paperForPrinterProfile({
    required bool isThermal,
    required double widthMm,
    required double heightMm,
  }) {
    return TemplatePaper(
      widthMm: widthMm,
      heightMm: heightMm,
      family: isThermal ? PaperFamily.thermal : PaperFamily.photo,
    );
  }
}
