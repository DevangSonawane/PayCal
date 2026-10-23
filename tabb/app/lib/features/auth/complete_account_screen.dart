import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/validators.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/features/auth/auth_identity.dart';
import 'package:paycal/features/auth/notifications_sheet.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';
import 'package:paycal/features/shell/main_shell.dart';

/// The account step that follows a Google sign-in.
///
/// Google hands over a verified email address but no password, so the member
/// still needs a name for the app and — if they want to sign in with an email
/// address later — a password. The email itself is read-only: it is the one
/// Google confirmed.
class CompleteAccountScreen extends StatefulWidget {
  const CompleteAccountScreen({super.key, required this.draft, this.email});

  final OnboardingDraft draft;

  /// The email Google confirmed. Empty when the account carries none.
  final String? email;

  @override
  State<CompleteAccountScreen> createState() => _CompleteAccountScreenState();
}

class _CompleteAccountScreenState extends State<CompleteAccountScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final email = widget.email ?? '';
    final user = PayCalRepositories.instance.auth.currentUser;
    _name = TextEditingController(
      text: (user?.name ?? '').trim().isNotEmpty
          ? user!.name
          : email.split('@').first,
    );
    _email = TextEditingController(text: email);
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final auth = PayCalRepositories.instance.auth;
      final name = _name.text.trim();
      if (name.isNotEmpty) await auth.setDisplayName(name);
      final password = _password.text;
      if (password.isNotEmpty) await auth.setPassword(password);
      syncAppIdentity(auth.currentUser);
      await PayCalRepositories.instance.hydrate();
      if (!mounted) return;
      // A member who already has a crib goes straight into the app, a new one
      // still has to set up the notifications and the first crib.
      final hasCrib = PayCalRepositories.instance.cribs.cachedCribs.isNotEmpty;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasCrib
              ? const MainShell()
              : NotificationsPage(draft: widget.draft),
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Unable to finish your account. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
                    'Finish your account',
                    style: AppTypography.headline.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Google already verified your email. Pick a name for the app '
                    'and, if you like, a password for later sign-ins.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppPalette.current.grey,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Display name',
                    hint: 'How your friends see you',
                    controller: _name,
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Tell us a name' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    readOnly: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PasswordTextField(
                    label: 'Password (optional)',
                    hint: 'Sign in with your email later',
                    controller: _password,
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) return null;
                      return Validators.password(password);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    label: 'Continue',
                    onPressed: _saving ? null : _continue,
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
}
