import 'package:flutter/material.dart';
import 'package:fotoboot_operator/models/local_photo.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key, required this.photo, this.compact = false});

  final LocalPhoto photo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (photo.syncStatus) {
      PhotoSyncStatus.synced => (
          Icons.cloud_done_outlined,
          const Color(0xFF1B7A3D),
          'Subida',
        ),
      PhotoSyncStatus.error => (
          Icons.error_outline,
          AppColors.red,
          'Error',
        ),
      PhotoSyncStatus.pendingDelete => (
          Icons.delete_outline,
          AppColors.grey,
          'Borrando',
        ),
      PhotoSyncStatus.pendingUpload => (
          Icons.cloud_off_outlined,
          AppColors.grey,
          'Local',
        ),
    };

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (photo.isPrinted) ...[
            const SizedBox(width: 8),
            const Icon(Icons.print, size: 16, color: AppColors.red),
            const SizedBox(width: 4),
            const Text(
              'Impresa',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
