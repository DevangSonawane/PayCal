import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/onboarding_progress.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';

/// Shared shell for the four onboarding questions: ruled-paper canvas,
/// back chip, chunky progress, accent badge + heavy headline and an
/// optional rotated "sticker" line for flavour.
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
    this.accent = AppPalette.current.pink,
    this.badgeIcon = Icons.auto_awesome_rounded,
    this.sticker,
    this.totalSteps = 5,
  });

  final int step;
  final String question;
  final String support;
  final Widget body;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final Color accent;
  final IconData badgeIcon;
  final String? sticker;
  final int totalSteps;

  bool get _onAccentIsDark => accent != AppPalette.current.lime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: const PinstripePainter(),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      0,
                    ),
                    child: Row(
                      children: [
                        if (onBack != null)
                          Semantics(
                            label: 'Back',
                            button: true,
                            child: GestureDetector(
                              onTap: onBack,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppPalette.current.ink,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_left,
                                  size: 26,
                                  color: AppPalette.current.ink,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OnboardingProgress(
                            currentStep: step,
                            totalSteps: totalSteps,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppPalette.current.ink,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${step + 1}/$totalSteps',
                            style: AppTypography.caption.copyWith(
                              color: AppPalette.current.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        160,
                      ),
                      child:
                          Column(
                                key: ValueKey(step),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppPalette.current.ink,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          badgeIcon,
                                          size: 19,
                                          color: _onAccentIsDark
                                              ? Colors.white
                                              : AppPalette.current.ink,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          question,
                                          style: AppTypography.headline
                                              .copyWith(
                                                color: AppPalette.current.ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    support,
                                    style: AppTypography.body.copyWith(
                                      color: AppPalette.current.grey,
                                    ),
                                  ),
                                  if (sticker != null) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    Transform.rotate(
                                      angle: -0.045,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: AppPalette.current.ink,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          sticker!,
                                          style: AppTypography.caption.copyWith(
                                            color: AppPalette.current.ink,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xxl),
                                  body,
                                ],
                              )
                              .animate()
                              .fadeIn(
                                duration: 220.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .slideY(
                                begin: 0.04,
                                end: 0,
                                duration: 260.ms,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.sm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.current.ink.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: PrimaryButton(
                        label: 'Continue',
                        onPressed: onContinue,
                        enabled: canContinue,
                      ),
                    ),
                    if (onSkip != null)
                      Center(
                        child: QuietTextButton(
                          label: 'Skip for now',
                          onPressed: onSkip!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
