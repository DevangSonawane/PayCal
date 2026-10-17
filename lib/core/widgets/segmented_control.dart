import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_typography.dart';

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({super.key, required this.tabs, required this.selected, required this.onSelect});

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.chipPill)),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.surfaceRaised : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.chipPill),
                  border: active ? Border.all(color: AppColors.border) : null,
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(color: active ? AppColors.textPrimary : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
