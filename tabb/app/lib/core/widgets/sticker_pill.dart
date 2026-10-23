import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/app_haptics.dart';

/// A pill that behaves like a sticker: when selected it pops slightly and
/// settles at a tiny hand-applied tilt, with a springy overshoot.
/// Taps fire a selection haptic plus a soft system tick.
class StickerPill extends StatelessWidget {
  const StickerPill({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.showCheck = false,
    this.selectedBg,
    this.selectedFg,
    this.unselectedBg,
    this.unselectedFg,
    this.horizontal = AppSpacing.lg,
    this.vertical = AppSpacing.md,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showCheck;
  final Color? selectedBg;
  final Color? selectedFg;
  final Color? unselectedBg;
  final Color? unselectedFg;
  // Ink-filled selections stay dark in both themes so their white label and
  // lime check never disappear when the adaptive foreground becomes light.
  Color get _selectedBg => selectedBg ?? AppColors.ink;
  Color get _selectedFg => selectedFg ?? Colors.white;
  Color get _unselectedBg => unselectedBg ?? AppPalette.current.card;
  Color get _unselectedFg => unselectedFg ?? AppPalette.current.ink;
  final double horizontal;
  final double vertical;

  double get _tilt {
    final seed = label.isEmpty ? 0 : (label.hashCode.abs() % 3) - 1;
    return selected ? seed * 0.016 : 0;
  }

  void _handleTap() {
    AppHaptics.soft();
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedRotation(
        turns: _tilt,
        duration: AppMotion.base,
        curve: Curves.easeOutBack,
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: AppMotion.base,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            decoration: BoxDecoration(
              color: selected ? _selectedBg : _unselectedBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected && showCheck) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppPalette.current.lime,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: selected ? _selectedFg : _unselectedFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
