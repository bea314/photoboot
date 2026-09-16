import 'package:fotoboot_operator/models/print_template.dart';

/// How many physical pages a photo batch needs for [template].
///
/// Ticket QR (`slotCount == 0`) does **not** consume photos — it is an
/// event/test layout, not a photo-batch template. Returns `0` so callers can
/// route to “Elige una plantilla…”.
int templatePageCount({
  required int photoCount,
  required int slotCount,
}) {
  if (slotCount <= 0) return 0;
  if (photoCount <= 0) return 0;
  return (photoCount + slotCount - 1) ~/ slotCount;
}

int pageCountForTemplate(PrintTemplate template, int photoCount) {
  return templatePageCount(
    photoCount: photoCount,
    slotCount: template.slotCount,
  );
}

/// Splits [photos] into pages of at most [slotCount] items (last page may be short).
List<List<T>> chunkPhotosForSlots<T>(List<T> photos, int slotCount) {
  if (slotCount <= 0 || photos.isEmpty) return const [];
  final pages = <List<T>>[];
  for (var i = 0; i < photos.length; i += slotCount) {
    final end = (i + slotCount > photos.length) ? photos.length : i + slotCount;
    pages.add(photos.sublist(i, end));
  }
  return pages;
}

/// True when the active template can lay out selected photos.
bool templateAcceptsPhotoBatch(PrintTemplate? template) {
  return template != null && template.slotCount > 0;
}
