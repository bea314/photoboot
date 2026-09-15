import 'dart:typed_data';

import 'package:flutter/widgets.dart';

enum BoothCameraPermission {
  granted,
  denied,
  prompt,
  notFound,
  unsupported,
}

abstract class BoothCameraSession {
  bool get isReady;
  Size? get previewSize;
  Widget buildPreview();
  Future<Uint8List> capture();
  Future<void> dispose();
}

class BoothCameraOpenResult {
  const BoothCameraOpenResult({
    required this.permission,
    this.session,
    this.error,
  });

  final BoothCameraPermission permission;
  final BoothCameraSession? session;
  final String? error;

  bool get isReady => session?.isReady ?? false;
}
