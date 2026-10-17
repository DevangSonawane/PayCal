import 'dart:async';
import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/features/auth/notifications_sheet.dart';
import 'package:paycal/features/onboarding/first_batch_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, required this.google, required this.draft});
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
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    await showNotificationsSheet(context);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => FirstBatchScreen(draft: widget.draft)),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.google) {
      // Google is already verified — skip ahead silently on first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, leading: const BackButton(color: AppColors.textPrimary)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check your inbox', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text('We sent a verification link to ${widget.email}.', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              const Spacer(),
              PrimaryButton(label: 'I verified — continue', onPressed: _continue),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: QuietTextButton(
                  label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
                  onPressed: _cooldown > 0 ? () {} : _resend,
                ),
              ),
              Center(child: QuietTextButton(label: 'Use a different email', onPressed: () => Navigator.of(context).pop())),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
