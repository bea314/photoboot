import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_factory.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

/// Igual que b584109: el clic dispara openBoothCamera() ya, sin awaits antes.
class CameraManager extends ChangeNotifier {
  BoothCameraSession? _session;
  BoothCameraStatus _status = BoothCameraStatus.needsPermission;
  String? _error;
  bool _opening = false;
  var _disposed = false;

  BoothCameraSession? get session => _session;
  BoothCameraStatus get status => _status;
  String? get error => _error;
  bool get isOpening => _opening;
  bool get isReady => _session?.isReady ?? false;

  Future<void> open({required bool userGesture}) async {
    if (_disposed || _opening || isReady) return;

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
      final old = _session;
      _session = result.session;
      _status = result.status;
      _error = result.status == BoothCameraStatus.ready ? null : result.message;
      if (old != null) unawaited(old.dispose());
    } catch (e) {
      debugPrint('❌ CameraManager: $e');
      _session = null;
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
    final current = _session;
    _session = null;
    unawaited(current?.dispose() ?? Future<void>.value());
    super.dispose();
  }
}
