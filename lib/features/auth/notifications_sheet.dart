import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/features/onboarding/first_batch_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

/// Full-screen notifications opt-in step (was a sheet floating over the
/// verify-email page — now its own opaque stop in the flow).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.draft});

  final OnboardingDraft draft;

  void _go(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => FirstBatchScreen(draft: draft)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppPalette.current.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: AppPalette.current.ink,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppPalette.current.pink,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppPalette.current.ink, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Never miss a split',
                        style: AppTypography.headline.copyWith(
                          color: AppPalette.current.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'A quiet nudge when money moves. No spam, no streaks, no guilt trips.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _line('New expenses in your batches'),
                _line('Payment requests and reminders'),
                _line('Weekly quiet summaries'),
                const Spacer(),
                PrimaryButton(
                  label: 'Turn on notifications',
                  onPressed: () => _go(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: QuietTextButton(
                    label: 'Not now',
                    onPressed: () => _go(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String t) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppPalette.current.lime,
            shape: BoxShape.circle,
            border: Border.all(color: AppPalette.current.ink, width: 1.5),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: AppPalette.current.ink,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            t,
            style: AppTypography.body.copyWith(
              color: AppPalette.current.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
