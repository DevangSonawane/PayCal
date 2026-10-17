import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';

class QuietTextButton extends StatelessWidget {
  const QuietTextButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(label, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
    );
  }
}
