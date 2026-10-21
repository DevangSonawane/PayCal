import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/features/shell/main_shell.dart';
import 'package:paycal/features/auth/auth_identity.dart';
import 'package:paycal/features/auth/complete_account_screen.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  StreamSubscription<AuthState>? _authChanges;

  @override
  void initState() {
    super.initState();
    if (!PayCalRepositories.instance.isRemote) return;
    _authChanges = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session != null) unawaited(_finishGoogleSignIn());
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _authChanges?.cancel();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (!AppConfig.hasSupabaseConfiguration ||
        !PayCalRepositories.instance.isRemote) {
      _showError(
        'The PayCal backend is not available in this build. Run with .env.json.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await PayCalRepositories.instance.auth.signInWithGoogle();
    } on RepositoryException catch (error) {
      if (mounted) _showError(error.message);
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (mounted) _showError('Unable to start Google sign-in.');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishGoogleSignIn() async {
    if (!mounted || !_busy) return;
    final auth = PayCalRepositories.instance.auth;
    syncAppIdentity(auth.currentUser);
    await PayCalRepositories.instance.hydrate();
    if (!mounted) return;
    final user = auth.currentUser;
    if (user != null && !user.hasPassword) {
      // Google brought no password, so the member picks one before they can
      // sign in with their email address later.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CompleteAccountScreen(
            draft: OnboardingDraft(),
            email: user.email,
          ),
        ),
        (route) => false,
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  Future<void> _signIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final user = await PayCalRepositories.instance.auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      syncAppIdentity(user);
      await PayCalRepositories.instance.hydrate();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (r) => false,
      );
    } on RepositoryException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showError('Unable to sign in. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAccountScreen(draft: OnboardingDraft()),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final error = Validators.email(_email.text);
    if (error != null) return _showError('Enter your email first.');
    setState(() => _busy = true);
    try {
      await PayCalRepositories.instance.auth.resetPassword(email: _email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on RepositoryException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (_) {
      if (mounted) _showError('Unable to send reset email.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: PinstripePainter(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Form(
              key: _form,
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
                  SizedBox(height: AppSpacing.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppPalette.current.lime,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppPalette.current.ink, width: 2),
                          ),
                        ),
                        child: Icon(
                          Icons.waving_hand_rounded,
                          size: 19,
                          color: AppPalette.current.ink,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Welcome back',
                          style: AppTypography.headline.copyWith(
                            color: AppPalette.current.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SecondaryButton(
                    label: _busy ? 'Opening Google…' : 'Continue with Google',
                    leading: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : SvgPicture.asset(
                            'assets/brand/google_g.svg',
                            width: 20,
                            height: 20,
                          ),
                    onPressed: _busy ? null : _continueWithGoogle,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Password',
                    hint: 'Your password',
                    controller: _password,
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: QuietTextButton(
                      label: 'Forgot password?',
                      onPressed: _busy ? null : _resetPassword,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Sign in',
                    onPressed: _signIn,
                    loading: _busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: QuietTextButton(
                      label: 'No account yet? Create one',
                      onPressed: _busy ? null : _createAccount,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
