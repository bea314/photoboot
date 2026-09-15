import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_factory.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/capture_feedback_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.photos});

  final PhotoController photos;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  BoothCameraSession? _session;
  BoothCameraPermission _permission = BoothCameraPermission.prompt;
  String? _cameraError;
  bool _opening = true;
  bool _busy = false;
  bool _saving = false;
  int? _countdown;
  bool _flash = false;
  Uint8List? _reviewBytes;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    setState(() {
      _opening = true;
      _cameraError = null;
    });

    final previous = _session;
    _session = null;
    await previous?.dispose();

    final result = await openBoothCamera();
    if (!mounted) {
      await result.session?.dispose();
      return;
    }

    setState(() {
      _session = result.session;
      _permission = result.permission;
      _cameraError = result.isReady ? null : result.error;
      _opening = false;
    });
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

    final session = _session;
    if (session == null || !session.isReady) {
      await _pickFallback();
      return;
    }

    setState(() {
      _busy = true;
      _countdown = 3;
    });

    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    setState(() => _countdown = null);

    try {
      await _save(await session.capture());
    } catch (_) {
      _showError('No se pudo tomar la foto');
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

  void _closeReview() {
    setState(() => _reviewBytes = null);
  }

  void _openGallery() {
    _closeReview();
    context.go('/gallery');
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('No se pudo completar'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final ready = session?.isReady ?? false;
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
                  child: _opening
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : _PermissionPanel(
                          permission: _permission,
                          message: _cameraError,
                          onEnable: _busy ? null : _openCamera,
                          onPick: _busy ? null : _pickFallback,
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
          if (ready && !_saving && _reviewBytes == null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _pickFallback,
                        child: const Text(
                          'Elegir foto',
                          style: TextStyle(color: AppColors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _busy ? null : _shoot,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _busy ? AppColors.grey : AppColors.red,
                            border: Border.all(color: AppColors.white, width: 5),
                          ),
                          child: _busy && _countdown == null
                              ? const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.white,
                                  size: 36,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    required this.permission,
    required this.onEnable,
    required this.onPick,
    this.message,
  });

  final BoothCameraPermission permission;
  final String? message;
  final VoidCallback? onEnable;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, color: AppColors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            message ??
                'Pulsa Activar cámara. Chrome pedirá permiso en esta pestaña.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.white, fontSize: 18),
          ),
          if (permission == BoothCameraPermission.unsupported) ...[
            const SizedBox(height: 8),
            const Text(
              'Esta build está preparada para probar en web.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          if (permission != BoothCameraPermission.unsupported)
            FilledButton(
              onPressed: onEnable,
              child: const Text('Activar cámara'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onPick,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.white, width: 2),
            ),
            child: const Text('Elegir foto'),
          ),
        ],
      ),
    );
  }
}
