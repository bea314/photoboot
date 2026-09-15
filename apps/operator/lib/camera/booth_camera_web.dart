import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:web/web.dart' as web;

const bool kBoothCameraSupported = true;

/// Safari no implementa bien `navigator.permissions.query({name:'camera'})`.
/// Solo la usamos como pista para la UI; nunca bloqueamos getUserMedia por ella.
Future<BoothCameraPermission> requestBoothCameraPermission() {
  return _peekPermission();
}

Future<BoothCameraOpenResult> openBoothCamera({
  bool fromUserGesture = false,
}) async {
  debugPrint('📷 openBoothCamera: fromUserGesture=$fromUserGesture');

  // Auto-abrir solo si el navegador reporta permiso persistente.
  // Con gesto de usuario siempre intentamos getUserMedia (Safari/Chrome).
  if (!fromUserGesture) {
    final peek = await _peekPermission();
    debugPrint('📷 Permiso (pista): $peek');
    if (peek != BoothCameraPermission.granted) {
      return BoothCameraOpenResult(
        permission: peek,
        error: BoothCameraMessages.forPermission(
          peek == BoothCameraPermission.denied
              ? BoothCameraPermission.denied
              : BoothCameraPermission.prompt,
        ),
      );
    }
  }

  try {
    await _stopActiveVideoTracks();

    debugPrint('🔍 Buscando cámaras...');
    final cameras = await availableCameras();
    debugPrint('🔍 Cámaras: ${cameras.length}');

    if (cameras.isEmpty) {
      return BoothCameraOpenResult(
        permission: BoothCameraPermission.notFound,
        error: BoothCameraMessages.forPermission(BoothCameraPermission.notFound),
      );
    }

    final preferred = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    debugPrint('📷 Cámara: ${preferred.name}');

    final controller = CameraController(
      preferred,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    debugPrint('🔄 Inicializando...');
    await controller.initialize();
    debugPrint('✅ Cámara lista');

    return BoothCameraOpenResult(
      permission: BoothCameraPermission.granted,
      session: _WebCameraSession(controller),
    );
  } on CameraException catch (error) {
    debugPrint('❌ CameraException: ${error.code} - ${error.description}');
    await _stopActiveVideoTracks();
    return _failedOpen(error.code, error.description ?? error.code);
  } catch (error, stack) {
    debugPrint('❌ Error: $error\n$stack');
    await _stopActiveVideoTracks();
    return _failedOpen(error.toString(), error.toString());
  }
}

Future<BoothCameraOpenResult> _failedOpen(String code, String detail) async {
  final text = '$code $detail'.toLowerCase();
  debugPrint('🔍 Error: $code | $detail');

  if (text.contains('notfound') || text.contains('devicesnotfound')) {
    return BoothCameraOpenResult(
      permission: BoothCameraPermission.notFound,
      error: BoothCameraMessages.forPermission(BoothCameraPermission.notFound),
    );
  }

  // Denegado permanente (bloqueado en ajustes del navegador).
  if (text.contains('permissiondenied') ||
      text.contains('notallowederror') ||
      text.contains('cameraaccessdenied')) {
    final queried = await _queryPermission();
    if (queried == BoothCameraPermission.denied) {
      return BoothCameraOpenResult(
        permission: BoothCameraPermission.denied,
        error: BoothCameraMessages.forPermission(BoothCameraPermission.denied),
      );
    }
    // Permiso no bloqueado pero falló: otra pestaña, cámara ocupada, o
    // Safari necesita otro clic tras el diálogo de permiso.
    return BoothCameraOpenResult(
      permission: BoothCameraPermission.prompt,
      error: BoothCameraMessages.openFailedBusy,
    );
  }

  return BoothCameraOpenResult(
    permission: BoothCameraPermission.prompt,
    error: BoothCameraMessages.openFailedRetry,
  );
}

Future<BoothCameraPermission> _peekPermission() async {
  return await _queryPermission() ?? BoothCameraPermission.prompt;
}

Future<BoothCameraPermission?> _queryPermission() async {
  try {
    final descriptor = JSObject();
    descriptor.setProperty('name'.toJS, 'camera'.toJS);
    final status =
        await web.window.navigator.permissions.query(descriptor).toDart;
    return switch (status.state) {
      'granted' => BoothCameraPermission.granted,
      'denied' => BoothCameraPermission.denied,
      'prompt' => BoothCameraPermission.prompt,
      _ => null,
    };
  } catch (_) {
    // Safari: Permissions API no soportada → desconocido, no bloquear.
    return null;
  }
}

/// Libera streams de video huérfanos (crítico al reintentar en Safari/Chrome).
Future<void> _stopActiveVideoTracks() async {
  try {
    final videos = web.document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      final node = videos.item(i);
      if (node is! web.HTMLVideoElement) continue;
      final stream = node.srcObject;
      if (stream == null) continue;
      final mediaStream = stream as web.MediaStream;
      for (final track in mediaStream.getTracks().toDart) {
        track.stop();
      }
      node.srcObject = null;
    }
    debugPrint('🧹 Video tracks liberados');
  } catch (e) {
    debugPrint('⚠️ No se pudieron liberar tracks: $e');
  }
}

class _WebCameraSession implements BoothCameraSession {
  _WebCameraSession(this._controller);

  final CameraController _controller;
  bool _disposed = false;

  @override
  bool get isReady => !_disposed && _controller.value.isInitialized;

  @override
  Size? get previewSize => _controller.value.previewSize;

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<Uint8List> capture() async {
    if (_disposed) {
      throw StateError('Cámara ya cerrada');
    }
    final file = await _controller.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      await _controller.dispose();
    } catch (e) {
      debugPrint('⚠️ dispose controller: $e');
    }
    await _stopActiveVideoTracks();
  }
}
