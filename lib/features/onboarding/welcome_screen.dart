import 'package:flutter/material.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/text_fx.dart';
import 'package:paycal/features/auth/sign_in_screen.dart';
import 'package:paycal/features/onboarding/onboarding_flow.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppPalette.current.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        color: AppPalette.current.lime,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppConfig.appName,
                      style: AppTypography.title.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _WelcomeHero(),
                        const SizedBox(height: AppSpacing.xxl),
                        SquigglyUnderline(
                          child: Text(
                            'Split bills,\nkeep friendships.',
                            style: AppTypography.display.copyWith(
                              color: AppPalette.current.ink,
                              fontWeight: FontWeight.w800,
                              height: 1.04,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No awkward maths, no spreadsheets, and no chasing anyone for last night’s pizza.',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppPalette.current.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PrimaryButton(
                  label: 'Get started',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingFlow()),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: AppTypography.body.copyWith(
                        color: AppPalette.current.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      ),
                      child: Text(
                        'Sign in',
                        style: AppTypography.label.copyWith(
                          color: AppPalette.current.pink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'By continuing you agree to our Terms and Privacy Policy',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat geometric hero card: white/lime split with a purple wedge, outlined
/// rings and Penny the mascot — mirrors the home screen's hero language.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 244,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _WelcomeHeroPainter())),
          Positioned(
            left: 18,
            top: 18,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.current.lime,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.current.ink, width: 1.5),
                ),
                child: Text(
                  'hi there!',
                  style: AppTypography.label.copyWith(
                    color: AppPalette.current.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppPalette.current.card,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppPalette.current.ink, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 66,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppPalette.current.page,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppPalette.current.pink, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            left: 26,
            bottom: 6,
            child: Image.asset(
              'assets/mascot/penny_smiling.png',
              width: 176,
              height: 176,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHeroPainter extends CustomPainter {
  const _WelcomeHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = Colors.white);

    // Lime lower-right block, cut by a diagonal.
    final lime = Path()
      ..moveTo(0, size.height * 0.56)
      ..lineTo(size.width, size.height * 0.30)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(lime, Paint()..color = AppPalette.current.lime);

    // Purple wedge in the bottom-left corner.
    final wedge = Path()
      ..moveTo(0, size.height * 0.78)
      ..lineTo(size.width * 0.44, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wedge, Paint()..color = AppPalette.current.purple);

    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppPalette.current.ink,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
