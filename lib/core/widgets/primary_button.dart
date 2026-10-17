import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.enabled = true});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled || loading;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: SizedBox(
        width: double.infinity,
        height: AppSpacing.buttonHeight,
        child: ElevatedButton(
          onPressed: disabled
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed?.call();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.inputButton)),
          ).copyWith(
            animationDuration: AppMotion.fast,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                )
              : Text(label, style: AppTypography.label.copyWith(color: AppColors.onPrimary)),
        ),
      ),
    );
  }
}
