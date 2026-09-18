import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:web/web.dart' as web;

/// En web no usamos el plugin `camera`. Su `availableCameras()` abre y cierra
/// la cámara dos veces (una para pedir permiso y otra por dispositivo, para
/// leer el facingMode) antes de que `initialize()` la abra de nuevo para el
/// preview. Safari solo concede getUserMedia dentro del gesto del usuario, así
/// que esas llamadas encadenadas fallan, y en macOS el ciclo abrir/cerrar deja
/// el dispositivo ocupado.
///
/// Aquí pedimos el stream una sola vez y montamos el <video> como platform
/// view, que es lo que el navegador espera.

int _viewTypeSeed = 0;

Future<BoothCameraResult> openBoothCamera({bool userGesture = false}) async {
  if (!web.window.isSecureContext) {
    return const BoothCameraResult(
      status: BoothCameraStatus.unsupported,
      message: BoothCameraMessages.insecureContext,
    );
  }

  if (web.window.navigator.mediaDevices.isUndefinedOrNull) {
    return const BoothCameraResult(
      status: BoothCameraStatus.unsupported,
      message: BoothCameraMessages.unsupported,
    );
  }

  web.MediaStream? stream;
  try {
    stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            // facingMode como valor ideal (no `exact`): si no hay cámara
            // frontal el navegador elige otra en vez de fallar.
            video: <String, String>{'facingMode': 'user'}.jsify()!,
            audio: false.toJS,
          ),
        )
        .toDart;

    return BoothCameraResult(
      status: BoothCameraStatus.ready,
      session: await _WebCameraSession.attach(stream),
    );
  } catch (error) {
    _stopStream(stream);
    return _resultFromError(error.toString());
  }
}

void _stopStream(web.MediaStream? stream) {
  if (stream == null) return;
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
}

/// El navegador rechaza getUserMedia con un DOMException cuyo texto es del
/// tipo "NotAllowedError: Permission denied".
BoothCameraResult _resultFromError(String error) {
  final text = error.toLowerCase();

  if (text.contains('notallowed') ||
      text.contains('permissiondenied') ||
      text.contains('security')) {
    return const BoothCameraResult(
      status: BoothCameraStatus.denied,
      message: BoothCameraMessages.denied,
    );
  }
  if (text.contains('notfound') ||
      text.contains('devicesnotfound') ||
      text.contains('overconstrained')) {
    return const BoothCameraResult(
      status: BoothCameraStatus.notFound,
      message: BoothCameraMessages.notFound,
    );
  }
  if (text.contains('notreadable') ||
      text.contains('trackstart') ||
      text.contains('abort')) {
    return const BoothCameraResult(
      status: BoothCameraStatus.error,
      message: BoothCameraMessages.busy,
    );
  }

  // Dejamos el error crudo a la vista: es lo que hace falta para diagnosticar
  // un caso que no esté contemplado arriba.
  return BoothCameraResult(
    status: BoothCameraStatus.error,
    message: '${BoothCameraMessages.openFailed}\n\n$error',
  );
}

class _WebCameraSession implements BoothCameraSession {
  _WebCameraSession._(this._stream, this._video, this._viewType);

  static Future<_WebCameraSession> attach(web.MediaStream stream) async {
    final video = web.HTMLVideoElement()
      ..autoplay = true
      // Safari exige muted + playsinline para reproducir sin pantalla completa.
      ..muted = true
      ..srcObject = stream;
    video.setAttribute('playsinline', 'true');
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';

    final viewType = 'fotoboot-camera-${_viewTypeSeed++}';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => video,
    );

    await _waitForFirstFrame(video);
    try {
      await video.play().toDart;
    } catch (_) {
      // Autoplay bloqueado: el stream sigue vivo y la captura funciona igual.
    }

    return _WebCameraSession._(stream, video, viewType);
  }

  static Future<void> _waitForFirstFrame(web.HTMLVideoElement video) {
    if (video.videoWidth > 0) return Future<void>.value();

    final completer = Completer<void>();
    void onReady(web.Event event) {
      if (!completer.isCompleted) completer.complete();
    }

    final listener = onReady.toJS;
    video.addEventListener('loadedmetadata', listener);

    return completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () {})
        .whenComplete(
          () => video.removeEventListener('loadedmetadata', listener),
        );
  }

  final web.MediaStream _stream;
  final web.HTMLVideoElement _video;
  final String _viewType;
  var _disposed = false;

  @override
  bool get isReady => !_disposed && _stream.active;

  @override
  Size? get previewSize {
    final width = _video.videoWidth;
    final height = _video.videoHeight;
    if (width == 0 || height == 0) return null;
    return Size(width.toDouble(), height.toDouble());
  }

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  @override
  Future<Uint8List> capture() async {
    final width = _video.videoWidth;
    final height = _video.videoHeight;
    if (width == 0 || height == 0) {
      throw StateError('El preview todavía no tiene imagen');
    }

    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    context.drawImage(_video, 0, 0);

    final dataUrl = canvas.toDataURL('image/jpeg', 0.92.toJS);
    return base64Decode(dataUrl.split(',').last);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _video.pause();
    _video.srcObject = null;
    _stopStream(_stream);
  }
}
