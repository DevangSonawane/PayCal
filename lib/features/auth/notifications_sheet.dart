import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/quiet_text_button.dart';

Future<void> showNotificationsSheet(BuildContext context) {
  return showAppBottomSheet(
    context: context,
    title: 'Never miss a split',
    builder: (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('New expenses in your batches'),
        _line('Payment requests and reminders'),
        _line('Weekly quiet summaries'),
      ],
    ),
    footer: Column(
      children: [
        PrimaryButton(label: 'Turn on notifications', onPressed: () => Navigator.of(context).pop()),
        Center(child: QuietTextButton(label: 'Not now', onPressed: () => Navigator.of(context).pop())),
      ],
    ),
  ).then((_) {});
}

Widget _line(String t) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.check, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(t, style: AppTypography.body.copyWith(color: AppColors.textSecondary))),
        ],
      ),
    );
