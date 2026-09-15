import 'package:flutter/material.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

class CameraTimerControl extends StatelessWidget {
  const CameraTimerControl({
    super.key,
    required this.busy,
    required this.menuOpen,
    required this.enabled,
    required this.seconds,
    required this.onToggleMenu,
    required this.onSelect,
  });

  final bool busy;
  final bool menuOpen;
  final bool enabled;
  final int seconds;
  final VoidCallback onToggleMenu;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IgnorePointer(
            ignoring: busy,
            child: Opacity(
              opacity: busy ? 0.45 : 1,
              child: Material(
                color: const Color(0xCC1A1A1A),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onToggleMenu,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 28,
                          color: enabled ? AppColors.red : AppColors.white,
                        ),
                        if (enabled)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${seconds}s',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (menuOpen) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE61A1A1A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimerOption(
                      label: 'Off',
                      selected: !enabled,
                      onTap: () => onSelect(null),
                    ),
                    for (final value in const [3, 5, 10])
                      _TimerOption(
                        label: '${value}s',
                        selected: enabled && seconds == value,
                        onTap: () => onSelect(value),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerOption extends StatelessWidget {
  const _TimerOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
