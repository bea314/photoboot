/// Printer profile definitions used for preview crop and raster targets.
/// IDs match API `GET /v1/printer/profiles`.
library;

enum PrinterProfileId {
  thermal80('thermal_80'),
  epsonL80504x6('epson_l8050_4x6');

  const PrinterProfileId(this.apiId);
  final String apiId;

  static PrinterProfileId fromApiId(String id) {
    return PrinterProfileId.values.firstWhere(
      (p) => p.apiId == id,
      orElse: () => PrinterProfileId.thermal80,
    );
  }
}

enum PrinterKind { thermal, epson }

class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.label,
    required this.kind,
    required this.aspectRatio,
    required this.frameLabel,
    this.paperWidthMm,
    this.targetDpi,
    this.thermalDotsWidth,
  });

  final PrinterProfileId id;
  final String label;
  final PrinterKind kind;

  /// Frame width / height for center-crop.
  final double aspectRatio;
  final String frameLabel;
  final int? paperWidthMm;
  final int? targetDpi;
  final int? thermalDotsWidth;

  static const List<PrinterProfile> defaults = [
    PrinterProfile(
      id: PrinterProfileId.thermal80,
      label: 'Térmica 80 mm',
      kind: PrinterKind.thermal,
      aspectRatio: 80 / 100,
      frameLabel: '80 × 100 mm (ticket)',
      paperWidthMm: 80,
      thermalDotsWidth: 576,
    ),
    PrinterProfile(
      id: PrinterProfileId.epsonL80504x6,
      label: 'Epson L8050 10×15',
      kind: PrinterKind.epson,
      aspectRatio: 10 / 15,
      frameLabel: '10 × 15 cm (4×6")',
      targetDpi: 300,
    ),
  ];

  static PrinterProfile byId(PrinterProfileId id) {
    return defaults.firstWhere((p) => p.id == id);
  }

  static PrinterProfile byApiId(String apiId) {
    return byId(PrinterProfileId.fromApiId(apiId));
  }
}
