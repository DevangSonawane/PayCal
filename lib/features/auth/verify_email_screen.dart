import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
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
  Timer? _poll;
  bool _waiting = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    if (widget.google) {
      // Google is already verified — skip ahead silently on first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
    } else {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  /// Watches for the session the confirmation link produces.
  ///
  /// The link opens the app, which exchanges the token and signs the member
  /// in. Until that happened there is no session, so the screen has to wait
  /// instead of pretending that the mail was confirmed.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final session = await PayCalRepositories.instance.auth.restoreSession();
      if (!mounted) return;
      if (session != null) {
        _poll?.cancel();
        _go();
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    try {
      await PayCalRepositories.instance.auth.resendConfirmation(widget.email);
    } on RepositoryException catch (error) {
      if (mounted) _showError(error.message);
      return;
    } catch (_) {
      if (mounted) _showError('Could not send the email again. Try later.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _cooldown = 30;
      _notice = null;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
        if (mounted) setState(() => _cooldown--);
      }
    });
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _continue() async {
    if (!widget.google) {
      final session = await PayCalRepositories.instance.auth.restoreSession();
      if (!mounted) return;
      if (session == null) {
        setState(() {
          _waiting = true;
          _notice = 'Still waiting for the link. Open it, then tap continue.';
        });
        return;
      }
    }
    _go();
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsPage(draft: widget.draft)),
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
                    SizedBox(width: AppSpacing.md),
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
                SizedBox(height: AppSpacing.md),
                Text(
                  'We sent a verification link to ${widget.email}. Tap it and you are in.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                if (_notice != null) ...[
                  SizedBox(height: AppSpacing.md),
                  Text(
                    _notice!,
                    style: AppTypography.body.copyWith(
                      color: AppPalette.current.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const Spacer(),
                PrimaryButton(
                  label: _waiting ? 'Still waiting…' : 'I verified — continue',
                  onPressed: _waiting ? null : _continue,
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
