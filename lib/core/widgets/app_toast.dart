import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/glass.dart';

void showAppToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Glass(
          radius: 999,
          blur: 24,
          fillOpacity: 0.86,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(message, style: AppTypography.label.copyWith(color: AppColors.textPrimary))),
            ],
          ),
        ),
      ),
    );
}
