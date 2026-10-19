import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confetti_burst.dart';
import 'package:paycal/core/widgets/pinstripe_rules.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/features/shell/main_shell.dart';

class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  void _finish(BuildContext context) {
    showConfettiBurst(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: AppPalette.current.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppPalette.current.ink, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.floatingShadow,
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.07,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.current.lime,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppPalette.current.ink,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'ALL SET',
                    style: AppTypography.caption.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Image.asset(
                'assets/mascot/penny_happy.png',
                width: 104,
                height: 104,
                fit: BoxFit.contain,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'You are all set!',
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Your first batch is ready to roll. Go split something.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppPalette.current.grey,
                ),
              ),
              SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Start splitting',
                onPressed: () => Navigator.of(dialogContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => MainShell()),
                  (r) => false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const link = 'https://paycal.app/join/our-flat-8X2K';
    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: CustomPaint(
        painter: PinstripePainter(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppPalette.current.pink,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppPalette.current.ink, width: 2),
                        ),
                      ),
                      child: Icon(
                        Icons.group_outlined,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Add your people',
                        style: AppTypography.headline.copyWith(
                          color: AppPalette.current.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'New members need your approval before they can join.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppPalette.current.lime,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppPalette.current.ink, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: AppPalette.current.ink,
                        size: 26,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Invite now, dodge the “who owes what?” texts later.',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppPalette.current.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.current.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppPalette.current.ink,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          link,
                          style: AppTypography.body.copyWith(
                            color: AppPalette.current.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: link));
                          showAppToast(context, 'Invite link copied');
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppPalette.current.ink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppPalette.current.lime,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                SecondaryButton(
                  label: 'Invite by email or username',
                  onPressed: () => showAppToast(context, 'Invite sent'),
                ),
                Spacer(),
                PrimaryButton(
                  label: 'Share invite link',
                  onPressed: () async {
                    Clipboard.setData(ClipboardData(text: link));
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          text: 'Join my batch on PayCal: $link',
                          subject: 'PayCal invite',
                        ),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        showAppToast(
                          context,
                          'Invite link copied — share it anywhere',
                        );
                      }
                    }
                  },
                ),
                Center(
                  child: QuietTextButton(
                    label: 'Skip for now',
                    onPressed: () => _finish(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
