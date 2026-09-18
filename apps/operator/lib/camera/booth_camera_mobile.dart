import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

Future<BoothCameraResult> openBoothCamera({bool userGesture = false}) async {
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
    return BoothCameraResult(
      status: _statusFromCameraException(e),
      message: e.description ?? e.code,
    );
  } catch (e) {
    await controller?.dispose();
    return BoothCameraResult(
      status: BoothCameraStatus.error,
      message: e.toString(),
    );
  }
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
  Widget buildPreview() => CameraPreview(_controller);

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
