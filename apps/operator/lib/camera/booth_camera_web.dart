import 'dart:js_interop';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:web/web.dart' as web;

const bool kBoothCameraSupported = true;

Future<BoothCameraPermission> requestBoothCameraPermission() async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            video: true.toJS,
            audio: false.toJS,
          ),
        )
        .toDart;
    _stopTracks(stream);
    return BoothCameraPermission.granted;
  } catch (error) {
    return _mapBrowserError(error);
  }
}

Future<BoothCameraOpenResult> openBoothCamera() async {
  final permission = await requestBoothCameraPermission();
  if (permission != BoothCameraPermission.granted) {
    return BoothCameraOpenResult(
      permission: permission,
      error: _messageFor(permission),
    );
  }

  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      return const BoothCameraOpenResult(
        permission: BoothCameraPermission.notFound,
        error: 'Chrome no encontró ninguna cámara.',
      );
    }

    final preferred = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      preferred,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    return BoothCameraOpenResult(
      permission: BoothCameraPermission.granted,
      session: _WebCameraSession(controller),
    );
  } on CameraException catch (error) {
    return BoothCameraOpenResult(
      permission: _mapCameraException(error),
      error: error.description ?? error.code,
    );
  } catch (error) {
    return BoothCameraOpenResult(
      permission: _mapBrowserError(error),
      error: error.toString(),
    );
  }
}

void _stopTracks(web.MediaStream stream) {
  final tracks = stream.getTracks().toDart;
  for (final track in tracks) {
    track.stop();
  }
}

BoothCameraPermission _mapBrowserError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('notfound') || text.contains('devicesnotfound')) {
    return BoothCameraPermission.notFound;
  }
  if (text.contains('notallowed') ||
      text.contains('permission') ||
      text.contains('securityerror') ||
      text.contains('denied')) {
    return BoothCameraPermission.denied;
  }
  return BoothCameraPermission.denied;
}

BoothCameraPermission _mapCameraException(CameraException error) {
  final code = error.code.toLowerCase();
  if (code.contains('permission')) {
    return BoothCameraPermission.denied;
  }
  if (code.contains('notfound') || code.contains('unavailable')) {
    return BoothCameraPermission.notFound;
  }
  return BoothCameraPermission.denied;
}

String _messageFor(BoothCameraPermission permission) {
  return switch (permission) {
    BoothCameraPermission.denied =>
      'Chrome bloqueó la cámara. En la barra de dirección, permite Cámara y pulsa Activar cámara.',
    BoothCameraPermission.notFound => 'No hay cámara en este equipo.',
    BoothCameraPermission.prompt =>
      'Pulsa Activar cámara para que Chrome pida el permiso.',
    BoothCameraPermission.unsupported =>
      'La cámara web no está disponible en esta compilación.',
    BoothCameraPermission.granted => '',
  };
}

class _WebCameraSession implements BoothCameraSession {
  _WebCameraSession(this._controller);

  final CameraController _controller;

  @override
  bool get isReady => _controller.value.isInitialized;

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
  Future<void> dispose() => _controller.dispose();
}
