import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/core/widgets/text_fx.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.mascot = 'assets/mascot/penny_thinking.png',
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final String mascot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppPalette.current.chip,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppPalette.current.ink, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -0.05,
              child: Image.asset(
                mascot,
                width: 104,
                height: 104,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            MarkerHighlight(
              child: Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: AppTypography.body.copyWith(
                color: AppPalette.current.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
