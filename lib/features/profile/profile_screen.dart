import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
                child: const Row(
                  children: [
                    Avatar(initials: 'YO', size: 56),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You', style: AppTypography.titleSmall),
                          Text('you@example.com', style: AppTypography.body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _group(context, 'Account', ['Account details', 'Notifications', 'Privacy']),
              _group(context, 'Support', ['Help', 'Terms and Privacy']),
              GestureDetector(
                onTap: () async {
                  final ok = await showConfirmSheet(
                    context: context,
                    title: 'Delete account?',
                    body: 'This anonymises your profile. Outstanding balances stay visible to others.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (ok == true && context.mounted) showAppToast(context, 'Account deletion requested');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Delete account', style: AppTypography.label.copyWith(color: AppColors.oweText)),
                ),
              ),
              const Divider(color: AppColors.border),
              GestureDetector(
                onTap: () async {
                  final ok = await showConfirmSheet(
                    context: context,
                    title: 'Log out?',
                    body: 'You can sign back in anytime.',
                    confirmLabel: 'Log out',
                  );
                  if (ok == true && context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (r) => false,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_outlined, color: AppColors.textPrimary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Log out', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<String> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
        ...rows.map((r) => GestureDetector(
              onTap: () => showAppToast(context, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text(r, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary))),
                    const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                  ],
                ),
              ),
            )),
        const Divider(color: AppColors.border),
      ],
    );
  }
}
