import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/widgets/glass.dart';

import 'package:paycal/core/theme/app_typography.dart';

class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({super.key, required this.currentIndex, required this.onDestinationSelected, required this.onAddPressed});

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Glass(
          radius: AppRadii.chipPill,
          blur: 24,
          fillOpacity: 0.72,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _item(context, 0, Icons.home_outlined, Icons.home, 'Home'),
                _item(context, 1, Icons.group_outlined, Icons.group, 'Batches'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Semantics(
                    label: 'Add expense',
                    button: true,
                    child: GestureDetector(
                      onTap: onAddPressed,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: AppColors.onPrimary, size: 28),
                      ),
                    ),
                  ),
                ),
                _item(context, 2, Icons.receipt_long_outlined, Icons.receipt_long, 'Activity'),
                _item(context, 3, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData outline, IconData filled, String label) {
    final active = currentIndex == index;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: active,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onDestinationSelected(index),
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(active ? filled : outline, color: active ? AppColors.textPrimary : AppColors.textSecondary, size: 24),
                if (active)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(label, style: AppTypography.caption.copyWith(color: AppColors.textPrimary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
