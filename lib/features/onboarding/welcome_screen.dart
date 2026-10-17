import 'package:flutter/material.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/features/auth/sign_in_screen.dart';
import 'package:paycal/features/onboarding/onboarding_flow.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Penny mascot hero.
              Center(
                child: Image.asset(
                  'assets/mascot/penny_smiling.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Text('Welcome to ${AppConfig.appName}', style: AppTypography.display.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Split bills with the people you live and travel with. No awkward math.',
                style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Get started',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingFlow())),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account?', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                  QuietTextButton(
                    label: 'Sign in',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  'By continuing you agree to our Terms and Privacy Policy',
                  style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
