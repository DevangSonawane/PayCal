import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/core/widgets/status_chip.dart';

/// Debug-only gallery. Not wired into the app; open manually when needed.
class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Gallery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Display', style: AppTypography.display.copyWith(color: AppColors.textPrimary)),
            Text('Headline', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
            Text('Title', style: AppTypography.title.copyWith(color: AppColors.textPrimary)),
            Text('Body large', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(label: 'Primary', onPressed: () {}),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(label: 'Secondary', onPressed: () {}),
            const SizedBox(height: AppSpacing.md),
            const Wrap(
              spacing: 8,
              children: [
                StatusChip(label: 'Pending', status: ChipStatus.pending),
                StatusChip(label: 'Confirmed', status: ChipStatus.confirmed),
                StatusChip(label: 'Disputed', status: ChipStatus.disputed),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(children: [Avatar(initials: 'AS'), SizedBox(width: 8), Avatar(initials: 'RK')]),
          ],
        ),
      ),
    );
  }
}
