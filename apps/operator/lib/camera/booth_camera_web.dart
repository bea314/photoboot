import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:web/web.dart' as web;

/// Web: getUserMedia nativo. El plugin `camera` abre/cierra el dispositivo varias
/// veces y falla aunque el permiso del sitio esté concedido.

int _viewTypeSeed = 0;

Stream<void> watchWebCameraPermissionGranted() {
  web.PermissionStatus? permission;

  final controller = StreamController<void>.broadcast(
    onCancel: () {
      permission?.onchange = null;
    },
  );

  unawaited(_bindCameraPermissionListener(controller, (value) {
    permission = value;
  }));

  return controller.stream;
}

Future<void> _bindCameraPermissionListener(
  StreamController<void> controller,
  void Function(web.PermissionStatus status) remember,
) async {
  try {
    final status = await _permissionStatus();
    remember(status);
    if (status.state == 'granted' || controller.isClosed) return;

    status.onchange = ((web.Event _) {
      if (status.state == 'granted' && !controller.isClosed) {
        controller.add(null);
      }
    }).toJS;
  } catch (_) {}
}

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

  // IMPORTANTE: getUserMedia debe ser el primer `await`. Cualquier await antes
  // (limpiar tracks, permissions.query, etc.) rompe el "user gesture" de Chrome
  // y devuelve NotAllowedError aunque el permiso del sitio sea "granted".
  web.MediaStream? stream;
  Object? lastError;

  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
          )
          .toDart;
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
      debugPrint('📷 getUserMedia intento ${attempt + 1}: $error');
      if (attempt == 2 || !_isRetryableMediaError(error)) break;
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }

  if (stream == null) {
    return await _resultFromBrowserError(lastError?.toString() ?? 'unknown');
  }

  try {
    return BoothCameraResult(
      status: BoothCameraStatus.ready,
      session: await _WebCameraSession.attach(stream),
    );
  } catch (error) {
    _stopStream(stream);
    return await _resultFromBrowserError(error.toString());
  }
}

Future<BoothCameraStatus?> _readCameraPermission() async {
  try {
    final state = (await _permissionStatus()).state;
    return switch (state) {
      'granted' => BoothCameraStatus.ready,
      'denied' => BoothCameraStatus.denied,
      'prompt' => BoothCameraStatus.needsPermission,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

Future<web.PermissionStatus> _permissionStatus() async {
  final descriptor = JSObject();
  descriptor.setProperty('name'.toJS, 'camera'.toJS);
  return web.window.navigator.permissions.query(descriptor).toDart;
}

bool _isRetryableMediaError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('notreadable') ||
      text.contains('trackstart') ||
      text.contains('abort');
}

void _stopStream(web.MediaStream? stream) {
  if (stream == null) return;
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
}

Future<BoothCameraResult> _resultFromBrowserError(String error) async {
  final text = error.toLowerCase();

  // Sitio con permiso pero macOS niega el hardware a Chrome.
  if (text.contains('denied by system')) {
    return const BoothCameraResult(
      status: BoothCameraStatus.error,
      message: BoothCameraMessages.systemDenied,
    );
  }

  if (text.contains('notfound') || text.contains('devicesnotfound')) {
    return const BoothCameraResult(
      status: BoothCameraStatus.notFound,
      message: BoothCameraMessages.notFound,
    );
  }

  if (text.contains('notallowed') || text.contains('permissiondenied')) {
    final permission = await _readCameraPermission();
    if (permission == BoothCameraStatus.denied) {
      return const BoothCameraResult(
        status: BoothCameraStatus.denied,
        message: BoothCameraMessages.denied,
      );
    }
    // Permiso del sitio concedido pero getUserMedia falló → falta gesto o cámara
    // ocupada; pedir clic explícito, no mostrar "denegado".
    return const BoothCameraResult(
      status: BoothCameraStatus.needsPermission,
      message: BoothCameraMessages.idle,
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

  return const BoothCameraResult(
    status: BoothCameraStatus.error,
    message: BoothCameraMessages.openFailed,
  );
}

class _WebCameraSession implements BoothCameraSession {
  _WebCameraSession._(this._stream, this._video, this._viewType);

  static Future<_WebCameraSession> attach(web.MediaStream stream) async {
    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..srcObject = stream;
    video.setAttribute('playsinline', 'true');

    final viewType = 'fotoboot-camera-${_viewTypeSeed++}';
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        video.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'cover';
        unawaited(video.play().toDart);
        return video;
      },
    );

    return _WebCameraSession._(stream, video, viewType);
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
  Widget buildPreview() => SizedBox.expand(
        child: HtmlElementView(viewType: _viewType),
      );

  @override
  Future<Uint8List> capture() async {
    await _waitForFrame();
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

  Future<void> _waitForFrame() async {
    if (_video.videoWidth > 0) return;
    final completer = Completer<void>();
    void onReady(web.Event _) {
      if (_video.videoWidth > 0 && !completer.isCompleted) completer.complete();
    }

    final listener = onReady.toJS;
    _video.addEventListener('loadeddata', listener);
    await completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () {})
        .whenComplete(() => _video.removeEventListener('loadeddata', listener));
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
