import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/primary_button.dart';

Future<bool?> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showAppBottomSheet<bool>(
    context: context,
    title: title,
    builder: (_) => Text(
      body,
      style: AppTypography.body.copyWith(color: AppPalette.current.textSecondary),
    ),
    footer: Column(
      children: [
        PrimaryButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.label.copyWith(color: AppPalette.current.text),
          ),
        ),
      ],
    ),
  );
}
