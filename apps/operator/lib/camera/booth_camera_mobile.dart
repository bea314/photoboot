import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

/// Android / iOS: plugin oficial [camera] con preview en vivo.
Future<BoothCameraResult> openMobileBoothCamera() async {
  CameraController? controller;
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      return const BoothCameraResult(
        status: BoothCameraStatus.notFound,
        message: BoothCameraMessages.notFound,
      );
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller.initialize();

    if (!controller.value.isInitialized) {
      await controller.dispose();
      return const BoothCameraResult(
        status: BoothCameraStatus.error,
        message: BoothCameraMessages.openFailed,
      );
    }

    return BoothCameraResult(
      status: BoothCameraStatus.ready,
      session: _MobileSession(controller),
    );
  } on CameraException catch (e) {
    await controller?.dispose();
    final status = _statusFromCameraException(e);
    return BoothCameraResult(
      status: status,
      message: _messageForStatus(status),
    );
  } catch (_) {
    await controller?.dispose();
    return const BoothCameraResult(
      status: BoothCameraStatus.error,
      message: BoothCameraMessages.openFailed,
    );
  }
}

String _messageForStatus(BoothCameraStatus status) {
  return switch (status) {
    BoothCameraStatus.denied => BoothCameraMessages.denied,
    BoothCameraStatus.notFound => BoothCameraMessages.notFound,
    _ => BoothCameraMessages.openFailed,
  };
}

BoothCameraStatus _statusFromCameraException(CameraException e) {
  final code = e.code.toLowerCase();
  if (code.contains('permission') || code.contains('denied')) {
    return BoothCameraStatus.denied;
  }
  if (code.contains('notfound') || code.contains('unavailable')) {
    return BoothCameraStatus.notFound;
  }
  return BoothCameraStatus.error;
}

class _MobileSession implements BoothCameraSession {
  _MobileSession(this._controller);

  final CameraController _controller;
  var _disposed = false;

  @override
  bool get isReady => !_disposed && _controller.value.isInitialized;

  @override
  Size? get previewSize => _controller.value.previewSize;

  @override
  Widget buildPreview() {
    final size = previewSize;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size?.width ?? 4,
        height: size?.height ?? 3,
        child: CameraPreview(_controller),
      ),
    );
  }

  @override
  Future<Uint8List> capture() async {
    final file = await _controller.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.dispose();
  }
}
