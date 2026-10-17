import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/data/mock_data.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
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
              Text('Activity', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.xxl),
              ...MockData.activity.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                              Text(a.subtitle, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(a.time, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
