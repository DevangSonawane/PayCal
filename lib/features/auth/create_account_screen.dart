import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/features/auth/verify_email_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.draft});
  final OnboardingDraft draft;
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit({bool google = false}) {
    if (!google && !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _saving = false);
      final email = google ? 'you@gmail.com' : _email.text.trim();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email, google: google, draft: widget.draft)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, leading: const BackButton(color: AppColors.textPrimary)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create your account.', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text('One last step.', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xxl),
                SecondaryButton(
                  label: 'Continue with Google',
                  leading: SvgPicture.asset('assets/brand/google_g.svg', width: 20, height: 20),
                  onPressed: () => _submit(google: true),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text('or', style: AppTypography.body.copyWith(color: AppColors.textTertiary)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(label: 'Full name', hint: 'Asha Sharma', controller: _name, validator: Validators.name, autofillHints: const ['name']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const ['email']),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  controller: _password,
                  obscureText: _obscure,
                  validator: Validators.password,
                  autofillHints: const ['new-password'],
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(label: 'Create account', onPressed: () => _submit(), loading: _saving),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'By continuing you agree to our Terms and Privacy Policy',
                  style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
