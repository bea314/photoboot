import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Resultado de abrir la cámara.
enum BoothCameraStatus {
  ready,
  needsPermission,
  denied,
  notFound,
  unsupported,
  error,
}

class BoothCameraResult {
  const BoothCameraResult({
    required this.status,
    this.session,
    this.message,
  });

  final BoothCameraStatus status;
  final BoothCameraSession? session;
  final String? message;

  bool get isReady => session?.isReady ?? false;
}

/// Sesión activa: preview + captura + cierre.
abstract class BoothCameraSession {
  bool get isReady;
  Size? get previewSize;
  Widget buildPreview();
  Future<Uint8List> capture();
  Future<void> dispose();
}
