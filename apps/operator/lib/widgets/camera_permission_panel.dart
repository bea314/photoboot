import 'package:flutter/material.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/pick_photo_button.dart';

class CameraPermissionPanel extends StatelessWidget {
  const CameraPermissionPanel({
    super.key,
    required this.status,
    required this.onEnable,
    required this.onPick,
    this.message,
    this.busy = false,
  });

  final BoothCameraStatus status;
  final String? message;
  final VoidCallback? onEnable;
  final VoidCallback? onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final headline = message ?? _defaultMessage(status);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined, color: AppColors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          if (status != BoothCameraStatus.unsupported)
            FilledButton(
              onPressed: busy ? null : onEnable,
              child: Text(BoothCameraMessages.buttonLabel(status)),
            ),
          const SizedBox(height: 12),
          PickPhotoButton(
            onPressed: onPick,
            enabled: !busy,
            variant: PickPhotoButtonVariant.panel,
          ),
        ],
      ),
    );
  }

  static String _defaultMessage(BoothCameraStatus status) {
    return switch (status) {
      BoothCameraStatus.needsPermission => BoothCameraMessages.idle,
      BoothCameraStatus.denied => BoothCameraMessages.denied,
      BoothCameraStatus.notFound => BoothCameraMessages.notFound,
      BoothCameraStatus.unsupported => BoothCameraMessages.unsupported,
      BoothCameraStatus.error => BoothCameraMessages.openFailed,
      BoothCameraStatus.ready => '',
    };
  }
}
