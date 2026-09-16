/// Runtime values for template text / QR placeholders (T3).
class TemplatePrintContext {
  const TemplatePrintContext({
    required this.evento,
    required this.fecha,
    required this.hora,
    this.eventUrl,
    this.now,
  });

  final String evento;
  final String fecha;
  final String hora;
  final String? eventUrl;

  /// Optional clock override for tests.
  final DateTime? now;

  factory TemplatePrintContext.fromEvent({
    required String eventName,
    String? eventUrl,
    DateTime? at,
  }) {
    final local = (at ?? DateTime.now()).toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return TemplatePrintContext(
      evento: eventName,
      fecha: '$d/$m/$y',
      hora: '$h:$min',
      eventUrl: eventUrl,
      now: local,
    );
  }

  /// Resolves `{{evento}}`, `{{fecha}}`, `{{hora}}`, `{{eventUrl}}`.
  String resolve(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .replaceAll('{{evento}}', evento)
        .replaceAll('{{fecha}}', fecha)
        .replaceAll('{{hora}}', hora)
        .replaceAll('{{eventUrl}}', eventUrl ?? '');
  }

  String? get qrPayload {
    final url = eventUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }
}
