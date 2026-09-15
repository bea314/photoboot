import 'package:flutter/material.dart';
import 'package:fotoboot_operator/camera/booth_camera_messages.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

enum PickPhotoButtonVariant { toolbar, panel }

class PickPhotoButton extends StatelessWidget {
  const PickPhotoButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.variant = PickPhotoButtonVariant.toolbar,
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final PickPhotoButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      PickPhotoButtonVariant.toolbar => FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xE61A1A1A),
            foregroundColor: AppColors.white,
            disabledBackgroundColor: const Color(0x991A1A1A),
            disabledForegroundColor: AppColors.grey,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.photo_outlined, color: AppColors.white),
          label: const Text(
            BoothCameraMessages.pickPhoto,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      PickPhotoButtonVariant.panel => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.white,
            side: const BorderSide(color: AppColors.white, width: 2),
          ),
          child: const Text(BoothCameraMessages.pickPhoto),
        ),
    };
  }
}
