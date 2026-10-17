import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/amount_field.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/primary_button.dart';

Future<void> showQuickAdd(BuildContext context) {
  final amount = TextEditingController();
  final desc = TextEditingController();
  return showAppBottomSheet(
    context: context,
    title: 'Add expense',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmountField(currencySymbol: '₹', controller: amount),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(label: 'What was it for?', hint: 'Dinner, rent, taxi…', controller: desc),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: ['Our flat', 'Paid by You', 'Split equally · 3', 'Today', 'Food']
              .map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                    child: Text(c, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        _Preview(amount: amount),
      ],
    ),
    footer: PrimaryButton(
      label: 'Add expense',
      onPressed: () {
        final minor = Money.tryParseToMinor(amount.text);
        if (minor == null || minor <= 0) {
          showAppToast(context, 'Enter an amount first');
          return;
        }
        Navigator.of(context).pop();
        showAppToast(context, 'Expense added');
      },
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview({required this.amount});
  final TextEditingController amount;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  void initState() {
    super.initState();
    widget.amount.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final minor = Money.tryParseToMinor(widget.amount.text) ?? 0;
    final per = minor ~/ 3;
    return Text(
      minor > 0 ? '${Money.format(per, 'INR')} each' : 'Enter an amount to preview shares',
      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
    );
  }
}
