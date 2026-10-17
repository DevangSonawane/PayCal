import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/features/shell/main_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
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
                Text('Welcome back', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.xxl),
                SecondaryButton(
                  label: 'Continue with Google',
                  leading: SvgPicture.asset('assets/brand/google_g.svg', width: 20, height: 20),
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (r) => false),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(label: 'Email', hint: 'you@example.com', controller: _email, validator: Validators.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(label: 'Password', hint: 'Your password', controller: _password, obscureText: true, validator: Validators.password),
                Align(
                  alignment: Alignment.centerRight,
                  child: QuietTextButton(label: 'Forgot password?', onPressed: () {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Sign in', onPressed: _signIn, loading: _busy),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
