import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confetti_burst.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/primary_button.dart';

Future<void> showSettleSheet(
  BuildContext context, {
  required String name,
  required int amountMinor,
  required String currency,
}) {
  var method = 0;
  return showAppBottomSheet(
    context: context,
    title: 'Settle up',
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay $name the full amount',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_rounded,
                  color: AppPalette.current.ink,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: MoneyText(
                    amount: amountMinor,
                    currency: currency,
                    style: AppTypography.displayAmount.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OptionTile(
            title: 'Ask $name to confirm',
            support: 'Pending until they confirm.',
            selected: method == 0,
            onTap: () => setState(() => method = 0),
          ),
          const SizedBox(height: AppSpacing.md),
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
        showConfettiBurst(context);
        showAppToast(
          context,
          method == 0
              ? 'Request sent to $name'
              : 'Marked as self-managed (${Money.format(amountMinor, currency)})',
        );
      },
    ),
  );
}
