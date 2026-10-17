import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    this.support,
    this.leading,
    this.selected = false,
    required this.onTap,
  });

  final String title;
  final String? support;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(
          color: selected ? AppColors.textPrimary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                      if (support != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(support!, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppColors.textPrimary, size: 24)
                else
                  const Icon(Icons.circle_outlined, color: AppColors.borderStrong, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
