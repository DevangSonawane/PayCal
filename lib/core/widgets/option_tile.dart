import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/app_haptics.dart';
import 'package:paycal/core/widgets/quirky_check.dart';

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    this.support,
    this.leading,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String? support;
  final Widget? leading;
  final bool selected;

  /// What happens when the tile is tapped.
  ///
  /// A null callback makes the tile inert, which is how an option that only
  /// the Crib Owner may use is shown to everybody else.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppPalette.current.lime : AppPalette.current.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: enabled
              ? () {
                  AppHaptics.soft();
                  onTap?.call();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleSmall.copyWith(
                          color: enabled
                              ? AppPalette.current.ink
                              : AppPalette.current.grey,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (support != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          support!,
                          style: AppTypography.caption.copyWith(
                            color: AppPalette.current.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                QuirkyCheck(selected: selected, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
