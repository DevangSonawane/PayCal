import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/core/widgets/status_chip.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';

class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, leading: const BackButton(color: AppColors.textPrimary)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expense.disputed) const StatusChip(label: 'Disputed', status: ChipStatus.disputed) else if (expense.unpaid) const StatusChip(label: 'Unpaid', status: ChipStatus.pending),
              const SizedBox(height: AppSpacing.md),
              MoneyText(amount: expense.totalMinor, currency: expense.currency, style: AppTypography.displayAmount),
              Text(expense.description, style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.xxl),
              _row('Date', '${expense.date.day}/${expense.date.month}/${expense.date.year}'),
              _row('Paid by', MockData.memberName(expense.payerId)),
              _row('Category', expense.category),
              _row('Split', 'Equally'),
              const SizedBox(height: AppSpacing.xxl),
              SecondaryButton(
                label: 'Flag a problem',
                onPressed: () => showAppToast(context, 'Thanks — the payer has been notified'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Edit',
                      onPressed: () => showAppToast(context, 'Editing is coming right up'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Delete',
                      onPressed: () async {
                        final ok = await showConfirmSheet(
                          context: context,
                          title: 'Delete expense?',
                          body: 'This removes it for everyone in the batch.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (ok == true && context.mounted) {
                          Navigator.of(context).pop();
                          showAppToast(context, 'Expense deleted');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('History', style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
              Text('Created · Edited once', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
          child: Row(
            children: [
              Expanded(child: Text(k, style: AppTypography.body.copyWith(color: AppColors.textSecondary))),
              Text(v, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      );
}
