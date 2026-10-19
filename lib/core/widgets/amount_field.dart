import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';

class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.currencySymbol,
    required this.controller,
    this.onChanged,
    this.autofocus = true,
  });

  final String currencySymbol;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              currencySymbol,
              style: AppTypography.label.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onChanged,
              style: AppTypography.displayAmount.copyWith(color: AppPalette.current.ink),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: AppTypography.displayAmount.copyWith(
                  color: AppPalette.current.grey,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
