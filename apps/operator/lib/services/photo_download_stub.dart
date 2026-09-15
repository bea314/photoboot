import 'dart:typed_data';

/// En nativo la foto ya vive en el dispositivo; la descarga JPEG es para web.
Future<bool> downloadPhotoBytes({
  required Uint8List bytes,
  required String filename,
}) async {
  assert(bytes.isNotEmpty || filename.isNotEmpty);
  return false;
}
