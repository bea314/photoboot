import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_factory.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

/// Detección Flutter (válida también en web). El router nativo vive en
/// booth_camera_io.dart con dart:io, que este archivo no puede importar.
bool get _isNativeDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

class CameraManager extends ChangeNotifier {
  BoothCameraSession? _session;
  BoothCameraStatus _status = BoothCameraStatus.needsPermission;
  String? _error;
  bool _opening = false;
  var _disposed = false;
  var _systemBlocked = false;
  StreamSubscription<void>? _permissionWatch;
  Timer? _permissionRetryTimer;

  CameraManager() {
    if (_isNativeDesktop) {
      _status = BoothCameraStatus.unsupported;
      _error = BoothCameraMessages.desktopHint;
    }
  }

  BoothCameraSession? get session => _session;
  BoothCameraStatus get status => _status;
  String? get error => _error;
  bool get isOpening => _opening;
  bool get isReady => _session?.isReady ?? false;

  Future<void> prepare() async {
    if (_disposed || _isNativeDesktop) return;

    if (kIsWeb) {
      await _permissionWatch?.cancel();
      _permissionWatch = watchWebCameraPermissionGranted().listen((_) {
        _schedulePermissionRetry();
      });
      _status = BoothCameraStatus.needsPermission;
      _error = null;
      notifyListeners();
      return;
    }

    await open(userGesture: false);
  }

  void _schedulePermissionRetry() {
    if (_disposed || _systemBlocked || isReady || _opening) return;
    _permissionRetryTimer?.cancel();
    // Un solo reintento tras conceder permiso en el diálogo del navegador.
    _permissionRetryTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_disposed && !_systemBlocked && !isReady && !_opening) {
        unawaited(open(userGesture: true));
      }
    });
  }

  Future<void> open({required bool userGesture}) async {
    if (_disposed || _opening || isReady) return;
    // El bloqueo de macOS solo evita reintentos automáticos; el botón sí reintenta.
    if (_systemBlocked && !userGesture) return;

    final pending = openBoothCamera(userGesture: userGesture);

    _opening = true;
    _error = null;
    notifyListeners();

    try {
      final result = await pending;
      if (_disposed) {
        await result.session?.dispose();
        return;
      }

      _systemBlocked = result.message == BoothCameraMessages.systemDenied;
      if (_systemBlocked) {
        await _permissionWatch?.cancel();
        _permissionRetryTimer?.cancel();
      }

      final old = _session;
      _session = result.session;
      _status = result.status;
      _error = result.status == BoothCameraStatus.ready ? null : result.message;
      if (old != null) unawaited(old.dispose());
    } catch (e) {
      debugPrint('❌ CameraManager: $e');
      final old = _session;
      _session = null;
      if (old != null) unawaited(old.dispose());
      _status = BoothCameraStatus.error;
      _error = BoothCameraMessages.unexpected;
    } finally {
      _opening = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _permissionRetryTimer?.cancel();
    unawaited(_permissionWatch?.cancel() ?? Future<void>.value());
    final current = _session;
    _session = null;
    unawaited(current?.dispose() ?? Future<void>.value());
    super.dispose();
  }
}
