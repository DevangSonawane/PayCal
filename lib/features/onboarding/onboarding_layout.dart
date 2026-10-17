import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/onboarding_progress.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';

class OnboardingLayout extends StatelessWidget {
  const OnboardingLayout({
    super.key,
    required this.step,
    required this.question,
    required this.support,
    required this.body,
    required this.canContinue,
    required this.onContinue,
    this.onBack,
    this.onSkip,
  });

  final int step;
  final String question;
  final String support;
  final Widget body;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    Semantics(
                      label: 'Back',
                      button: true,
                      child: GestureDetector(
                        onTap: onBack,
                        child: const SizedBox(width: 48, height: 48, child: Icon(Icons.chevron_left, size: 28)),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(child: OnboardingProgress(currentStep: step)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question, style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(support, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xxl),
                    body,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: 'Continue', onPressed: onContinue, enabled: canContinue),
                  if (onSkip != null)
                    Center(child: QuietTextButton(label: 'Skip for now', onPressed: onSkip!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
