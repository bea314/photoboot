import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_factory.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';

/// Gestor centralizado: una sola sesión de cámara, cierre limpio, sin race conditions.
class CameraManager extends ChangeNotifier {
  BoothCameraSession? _session;
  BoothCameraPermission _permission = BoothCameraPermission.prompt;
  String? _error;
  bool _isOpening = false;
  bool _disposed = false;
  bool _hadSession = false;

  BoothCameraSession? get session => _session;
  BoothCameraPermission get permission => _permission;
  String? get error => _error;
  bool get isOpening => _isOpening;
  bool get isReady => _session?.isReady ?? false;

  Future<void> openCamera({required bool fromUserGesture}) async {
    if (_disposed) return;
    if (_isOpening) return;
    if (_session?.isReady == true) return;

    _isOpening = true;
    _error = null;
    notifyListeners();

    final hadPrevious = _hadSession;
    try {
      await _closeCurrentSession();

      // Solo esperar si había una sesión previa (liberar hardware).
      if (hadPrevious) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      if (_disposed) return;

      final result = await openBoothCamera(fromUserGesture: fromUserGesture);
      if (_disposed) {
        await result.session?.dispose();
        return;
      }

      _session = result.session;
      _permission = result.permission;
      _error = result.error;
      _hadSession = result.isReady;

      if (result.isReady) {
        debugPrint('✅ CameraManager: cámara abierta');
      } else {
        debugPrint('⚠️ CameraManager: $_error');
      }
    } catch (e) {
      debugPrint('❌ CameraManager: $e');
      _error = BoothCameraMessages.unexpectedOpenError;
      _session = null;
    } finally {
      _isOpening = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retry() => openCamera(fromUserGesture: true);

  Future<void> _closeCurrentSession() async {
    final current = _session;
    if (current == null) return;

    _session = null;
    try {
      await current.dispose();
    } catch (e) {
      debugPrint('⚠️ Error al cerrar sesión: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_closeCurrentSession());
    super.dispose();
  }
}
