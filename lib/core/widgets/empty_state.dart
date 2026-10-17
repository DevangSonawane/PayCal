import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/secondary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, required this.actionLabel, required this.onAction});

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTypography.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
