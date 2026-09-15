import 'package:flutter/material.dart';
import 'package:fotoboot_operator/camera/booth_camera.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:fotoboot_operator/widgets/pick_photo_button.dart';

class CameraPermissionPanel extends StatelessWidget {
  const CameraPermissionPanel({
    super.key,
    required this.permission,
    required this.onEnable,
    required this.onPick,
    this.message,
    this.busy = false,
  });

  final BoothCameraPermission permission;
  final String? message;
  final VoidCallback? onEnable;
  final VoidCallback? onPick;
  final bool busy;

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
            message ?? BoothCameraMessages.webIdleHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.white, fontSize: 18),
          ),
          if (permission == BoothCameraPermission.unsupported) ...[
            const SizedBox(height: 8),
            const Text(
              BoothCameraMessages.unsupportedBuild,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          if (permission != BoothCameraPermission.unsupported)
            FilledButton(
              onPressed: busy ? null : onEnable,
              child: Text(BoothCameraMessages.enableLabel(permission)),
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
}
