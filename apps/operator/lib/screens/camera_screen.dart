import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fotoboot_operator/camera/camera_manager.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/camera_permission_panel.dart';
import 'package:fotoboot_operator/widgets/camera_shutter_button.dart';
import 'package:fotoboot_operator/widgets/camera_timer_control.dart';
import 'package:fotoboot_operator/widgets/capture_feedback_overlay.dart';
import 'package:fotoboot_operator/widgets/pick_photo_button.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.photos});

  final PhotoController photos;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late final CameraManager _cameraManager;
  bool _busy = false;
  bool _saving = false;
  int? _countdown;
  bool _flash = false;
  Uint8List? _reviewBytes;
  bool _timerEnabled = true;
  int _timerSeconds = 3;
  bool _timerMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _cameraManager = CameraManager();
    _cameraManager.addListener(_onCameraStateChanged);

    if (!kIsWeb) {
      _cameraManager.openCamera(fromUserGesture: false);
    }
  }

  @override
  void dispose() {
    _cameraManager.removeListener(_onCameraStateChanged);
    _cameraManager.dispose();
    super.dispose();
  }

  void _onCameraStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _shoot() async {
    if (_busy) return;
    if (widget.photos.eventId == null) {
      await widget.photos.refreshEvent();
      if (widget.photos.eventId == null) {
        _showError(widget.photos.error ?? 'Sin evento activo');
        return;
      }
    }

    final session = _cameraManager.session;
    if (session == null || !session.isReady) {
      await _pickFallback();
      return;
    }

    setState(() => _busy = true);

    if (_timerEnabled) {
      for (var i = _timerSeconds; i >= 1; i--) {
        if (!mounted) return;
        setState(() => _countdown = i);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _countdown = null);
    }

    try {
      await _save(await session.capture());
    } catch (e) {
      _showError('No se pudo tomar la foto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFallback() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;
      if (widget.photos.eventId == null) {
        await widget.photos.refreshEvent();
      }
      if (widget.photos.eventId == null) {
        _showError(widget.photos.error ?? 'Sin evento activo');
        return;
      }
      await _save(await picked.readAsBytes());
    } catch (_) {
      _showError('No se pudo usar esa imagen');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    setState(() {
      _flash = true;
      _saving = true;
      _reviewBytes = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (mounted) setState(() => _flash = false);

    try {
      await Future.wait([
        widget.photos.ingestCapture(bytes: data),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('No se pudo guardar la foto');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _reviewBytes = data;
    });
  }

  void _closeReview() => setState(() => _reviewBytes = null);

  void _openGallery() {
    _closeReview();
    context.go('/gallery');
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No se pudo completar'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _cameraManager.session;
    final ready = _cameraManager.isReady;
    final previewSize = session?.previewSize;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready && session != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize?.width ?? 4,
                height: previewSize?.height ?? 3,
                child: session.buildPreview(),
              ),
            )
          else
            ColoredBox(
              color: AppColors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _cameraManager.isOpening
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : CameraPermissionPanel(
                          permission: _cameraManager.permission,
                          message: _cameraManager.error,
                          busy: _busy,
                          onEnable: () =>
                              _cameraManager.openCamera(fromUserGesture: true),
                          onPick: _pickFallback,
                        ),
                ),
              ),
            ),
          if (_flash) const ColoredBox(color: AppColors.white),
          if (_countdown != null)
            Center(
              child: Text(
                '$_countdown',
                style: TextStyle(
                  fontSize: 160,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  shadows: [
                    Shadow(
                      color: AppColors.red.withValues(alpha: 0.8),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          if (ready && !_saving && _reviewBytes == null) ...[
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: PickPhotoButton(
                    enabled: !_busy,
                    onPressed: _pickFallback,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: CameraTimerControl(
                  busy: _busy,
                  menuOpen: _timerMenuOpen,
                  enabled: _timerEnabled,
                  seconds: _timerSeconds,
                  onToggleMenu: () {
                    if (_busy) return;
                    setState(() => _timerMenuOpen = !_timerMenuOpen);
                  },
                  onSelect: (seconds) {
                    setState(() {
                      _timerEnabled = seconds != null;
                      if (seconds != null) _timerSeconds = seconds;
                      _timerMenuOpen = false;
                    });
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: CameraShutterButton(
                busy: _busy,
                capturing: _busy && _countdown == null,
                onShoot: _shoot,
              ),
            ),
          ],
          if (_saving) const CaptureSavingOverlay(),
          if (_reviewBytes != null)
            CaptureSavedSheet(
              bytes: _reviewBytes!,
              onTakeAnother: _closeReview,
              onOpenGallery: _openGallery,
            ),
        ],
      ),
    );
  }
}
