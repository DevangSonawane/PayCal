import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/text_fx.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/features/auth/verify_email_screen.dart';
import 'package:paycal/features/auth/auth_identity.dart';
import 'package:paycal/features/auth/complete_account_screen.dart';
import 'package:paycal/features/auth/notifications_sheet.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  bool _saving = false;
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
    _authChanges?.cancel();
    super.dispose();
  }

  Future<void> _continue() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmailSignUpScreen(draft: widget.draft)),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (!PayCalRepositories.instance.isRemote) {
      _showError(
        'The Tabbb backend is not available in this build. Run with .env.json.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PayCalRepositories.instance.auth.signInWithGoogle();
    } on RepositoryException catch (error) {
      if (mounted) _showError(error.message);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) _showError('Unable to start Google sign-in.');
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// The browser handed the session back through the `paycal://auth/callback`
  /// deep link, so the member is signed in.
  Future<void> _finishGoogleSignIn() async {
    if (!mounted || !_saving) return;
    final auth = PayCalRepositories.instance.auth;
    syncAppIdentity(auth.currentUser);
    await PayCalRepositories.instance.hydrate();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CompleteAccountScreen(
          draft: widget.draft,
          email: auth.currentUser?.email,
        ),
      ),
      (route) => false,
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
                SizedBox(height: AppSpacing.md),
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
                                alignment: Alignment(0, -0.16),
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
                        SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
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
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'One account, and your groups come along for the ride.',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppPalette.current.grey,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.buttonHeight,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _continueWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.current.surface,
                              foregroundColor: AppPalette.current.ink,
                              disabledBackgroundColor: AppPalette.current.chip,
                              disabledForegroundColor: AppPalette.current.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                                side: BorderSide(
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

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final auth = PayCalRepositories.instance.auth;
      final created = await auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _email.text.trim().split('@').first,
      );
      syncAppIdentity(created ?? auth.currentUser);
      if (!mounted) return;
      // A confirmed account comes back with a session right away. Only an
      // account that still has to confirm its email needs the inbox step.
      final session = await auth.restoreSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => session != null
              ? NotificationsPage(draft: widget.draft)
              : VerifyEmailScreen(
                  email: _email.text.trim(),
                  google: false,
                  draft: widget.draft,
                ),
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Unable to create your account. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.current.page,
    body: CustomPaint(
      painter: PinstripePainter(),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Create your account',
                  style: AppTypography.headline.copyWith(
                    color: AppPalette.current.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use your email and choose a password.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.lg),
                PasswordTextField(
                  label: 'Password',
                  hint: 'Choose a secure password',
                  controller: _password,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  label: 'Create account',
                  onPressed: _saving ? null : _createAccount,
                  loading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
