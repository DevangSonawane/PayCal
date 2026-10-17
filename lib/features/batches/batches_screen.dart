import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/empty_state.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';

class BatchesScreen extends StatelessWidget {
  const BatchesScreen({super.key});

  int _netFor(Batch b) {
    final exps = MockData.expenses.where((e) => e.batchId == b.id).toList();
    final inputs = exps.map((e) => ExpenseInput(totalMinor: e.totalMinor, payerId: e.payerId, shares: e.shares)).toList();
    return BalanceEngine.nets(inputs, b.members.map((m) => m.id).toList())[MockData.meId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (MockData.batches.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: EmptyState(
              title: 'No batches yet',
              body: 'Create your first batch to start splitting.',
              actionLabel: 'Add expense',
              onAction: () => showQuickAdd(context),
            ),
          ),
        ),
      );
    }

    final nets = {for (final b in MockData.batches) b.id: _netFor(b)};
    final total = nets.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batches', style: AppTypography.headline.copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text('${MockData.batches.length} groups', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total across batches', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xs),
                    MoneyText(
                      amount: total.abs(),
                      currency: 'INR',
                      style: AppTypography.displayAmount,
                      direction: total > 0 ? MoneyDirection.owed : (total < 0 ? MoneyDirection.owe : null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ...MockData.batches.map((b) {
                final net = nets[b.id] ?? 0;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(b.name, style: AppTypography.title.copyWith(color: AppColors.textPrimary))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.chipPill)),
                              child: Text(b.currency, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            AvatarStack(initials: b.members.map((m) => m.initials).toList()),
                            const SizedBox(width: AppSpacing.sm),
                            Text('${b.members.length} members', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                            const Spacer(),
                            MoneyText(
                              amount: net.abs(),
                              currency: b.currency,
                              direction: net > 0 ? MoneyDirection.owed : (net < 0 ? MoneyDirection.owe : null),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
