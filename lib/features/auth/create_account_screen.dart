import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/text_fx.dart';
import 'package:paycal/features/auth/verify_email_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(
          email: 'you@gmail.com',
          google: true,
          draft: widget.draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: const PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
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
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPalette.current.ink, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 26,
                      color: AppPalette.current.ink,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 224,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppPalette.current.ink,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/onboarding/Cute Bear Finance Card Splash Screen.png',
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.16),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              bottom: -12,
                              child: Transform.rotate(
                                angle: -0.05,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.current.lime,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppPalette.current.ink,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'free to start',
                                    style: AppTypography.label.copyWith(
                                      color: AppPalette.current.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
                        SquigglyUnderline(
                          child: Text(
                            'Split together,\nsimply.',
                            style: AppTypography.display.copyWith(
                              color: AppPalette.current.ink,
                              fontWeight: FontWeight.w800,
                              height: 1.04,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'One account, and your groups come along for the ride.',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppPalette.current.grey,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.buttonHeight,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _continue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppPalette.current.ink,
                              disabledBackgroundColor: AppPalette.current.chip,
                              disabledForegroundColor: AppPalette.current.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: const BorderSide(
                                  color: AppPalette.current.ink,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/brand/google_g.svg',
                                  width: 21,
                                  height: 21,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Text(
                                  'Continue with Google',
                                  style: AppTypography.label.copyWith(
                                    color: AppPalette.current.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Continue with email',
                          onPressed: _continue,
                          loading: _saving,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: Text(
                            'No card needed. Ever.',
                            style: AppTypography.caption.copyWith(
                              color: AppPalette.current.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
