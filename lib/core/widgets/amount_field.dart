import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

class AmountField extends StatelessWidget {
  const AmountField({super.key, required this.currencySymbol, required this.controller, this.onChanged, this.autofocus = true});

  final String currencySymbol;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(currencySymbol, style: AppTypography.headline.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: onChanged,
              style: AppTypography.displayAmount.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTypography.displayAmount.copyWith(color: AppColors.textDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
