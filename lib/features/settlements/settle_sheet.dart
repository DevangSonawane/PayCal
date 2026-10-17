import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/primary_button.dart';

Future<void> showSettleSheet(BuildContext context, {required String name, required int amountMinor, required String currency}) {
  var method = 0;
  return showAppBottomSheet(
    context: context,
    title: 'Settle up',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pay $name the full amount', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          MoneyText(amount: amountMinor, currency: currency, style: AppTypography.displayAmount),
          const SizedBox(height: AppSpacing.lg),
          OptionTile(
            title: 'Ask $name to confirm',
            support: 'Pending until they confirm.',
            selected: method == 0,
            onTap: () => setState(() => method = 0),
          ),
          const SizedBox(height: AppSpacing.sm),
          OptionTile(
            title: 'Mark as settled myself',
            support: 'We can not verify the transfer. Labelled Self-managed.',
            selected: method == 1,
            onTap: () => setState(() => method = 1),
          ),
        ],
      ),
    ),
    footer: PrimaryButton(
      label: 'Record settlement',
      onPressed: () {
        Navigator.of(context).pop();
        showAppToast(context, method == 0 ? 'Request sent to $name' : 'Marked as self-managed (${Money.format(amountMinor, currency)})');
      },
    ),
  );
}
