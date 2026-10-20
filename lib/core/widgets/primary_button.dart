import 'package:flutter/material.dart';
import 'package:paycal/core/utils/app_haptics.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/press_scale.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.haptic = AppHapticStrength.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final AppHapticStrength haptic;

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || loading;
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: PressScale(
        child: ElevatedButton(
          onPressed: disabled
              ? null
              : () {
                  AppHaptics.trigger(haptic);
                  onPressed?.call();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.current.pink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppPalette.current.chip,
            disabledForegroundColor: AppPalette.current.grey,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: disabled
                    ? AppPalette.current.hairline
                    : AppPalette.current.ink,
                width: 1.5,
              ),
            ),
          ).copyWith(animationDuration: AppMotion.fast),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    key: ValueKey(label),
                    label,
                    style: AppTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
