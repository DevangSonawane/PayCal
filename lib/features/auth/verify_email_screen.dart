import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/features/auth/notifications_sheet.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.google,
    required this.draft,
  });
  final String email;
  final bool google;
  final OnboardingDraft draft;
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resend() {
    if (_cooldown > 0) return;
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _continue() async {
    if (!widget.google) {
      // Simulate polling success.
      await Future.delayed(Duration(milliseconds: 400));
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsPage(draft: widget.draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.google) {
      // Google is already verified — skip ahead silently on first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
    }
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
                        color: AppPalette.current.purple,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppPalette.current.ink, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Check your inbox',
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
                  'We sent a verification link to ${widget.email}. Tap it and you are in.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'I verified — continue',
                  onPressed: _continue,
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: QuietTextButton(
                    label: _cooldown > 0
                        ? 'Resend in ${_cooldown}s'
                        : 'Resend email',
                    onPressed: _cooldown > 0 ? () {} : _resend,
                  ),
                ),
                Center(
                  child: QuietTextButton(
                    label: 'Use a different email',
                    onPressed: () => Navigator.of(context).pop(),
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
}
