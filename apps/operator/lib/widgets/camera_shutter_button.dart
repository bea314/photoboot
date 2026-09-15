import 'package:flutter/material.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class CameraShutterButton extends StatelessWidget {
  const CameraShutterButton({
    super.key,
    required this.busy,
    required this.capturing,
    required this.onShoot,
  });

  final bool busy;
  final bool capturing;
  final VoidCallback onShoot;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + 18),
      child: GestureDetector(
        onTap: busy ? null : onShoot,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy ? AppColors.grey : AppColors.red,
            border: Border.all(color: AppColors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: capturing
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
    );
  }
}
