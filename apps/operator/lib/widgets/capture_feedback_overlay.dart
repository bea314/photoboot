import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class CaptureSavingOverlay extends StatelessWidget {
  const CaptureSavingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppColors.red,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Guardando foto…',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CaptureSavedSheet extends StatelessWidget {
  const CaptureSavedSheet({
    super.key,
    required this.bytes,
    required this.onTakeAnother,
    required this.onOpenGallery,
  });

  final Uint8List bytes;
  final VoidCallback onTakeAnother;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 700;

            final photo = ColoredBox(
              color: AppColors.surface,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            );

            if (split) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: photo),
                  Container(width: 1, color: const Color(0xFFE8E8E8)),
                  SizedBox(
                    width: (constraints.maxWidth * 0.34).clamp(300.0, 420.0),
                    child: _ReviewControls(
                      expand: true,
                      onTakeAnother: onTakeAnother,
                      onOpenGallery: onOpenGallery,
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: photo),
                _ReviewControls(
                  expand: false,
                  onTakeAnother: onTakeAnother,
                  onOpenGallery: onOpenGallery,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReviewControls extends StatelessWidget {
  const _ReviewControls({
    required this.expand,
    required this.onTakeAnother,
    required this.onOpenGallery,
  });

  final bool expand;
  final VoidCallback onTakeAnother;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: AppColors.red, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Foto guardada',
            style: TextStyle(
              color: AppColors.red,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ya está en la galería y se está subiendo.',
            style: TextStyle(color: AppColors.grey, fontSize: 16, height: 1.35),
          ),
          if (expand) const Spacer() else const SizedBox(height: 24),
          FilledButton(
            onPressed: onTakeAnother,
            child: const Text('Tomar otra'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onOpenGallery,
            child: const Text('Ver en galería'),
          ),
        ],
      ),
    );
  }
}
