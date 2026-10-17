import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/features/shell/main_shell.dart';

class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  void _finish(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(AppRadii.card)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.owedText, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('You are all set', style: AppTypography.title.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
    final nav = Navigator.of(context);
    Future.delayed(const Duration(milliseconds: 900), () {
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const link = 'https://paycal.app/join/our-flat-8X2K';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Text('Add your people', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text('New members need your approval before they can join.', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
                child: Row(
                  children: [
                    Expanded(child: Text(link, style: AppTypography.body.copyWith(color: AppColors.textPrimary))),
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppColors.textSecondary),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: link));
                        showAppToast(context, 'Invite link copied');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Invite by email or username',
                onPressed: () => showAppToast(context, 'Invite sent'),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Share invite link',
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: link));
                  showAppToast(context, 'Invite link copied — share it anywhere');
                },
              ),
              Center(child: QuietTextButton(label: 'Skip for now', onPressed: () => _finish(context))),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
