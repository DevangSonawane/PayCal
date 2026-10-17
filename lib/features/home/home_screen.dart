import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';

/// Account-level dashboard. Group lists and full transaction histories live in
/// the Batches and Activity tabs, respectively.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  int _netForBatch(Batch batch) {
    final expenses = MockData.expenses
        .where((expense) => expense.batchId == batch.id)
        .toList();
    final inputs = expenses
        .map(
          (expense) => ExpenseInput(
            totalMinor: expense.totalMinor,
            payerId: expense.payerId,
            shares: expense.shares,
          ),
        )
        .toList();
    return BalanceEngine.nets(
          inputs,
          batch.members.map((member) => member.id).toList(),
        )[MockData.meId] ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    var owed = 0;
    var owe = 0;
    for (final batch in MockData.batches) {
      final net = _netForBatch(batch);
      if (net > 0) {
        owed += net;
      } else {
        owe += -net;
      }
    }
    final attentionCount = MockData.expenses
        .where((expense) => expense.unpaid || expense.disputed)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              120,
            ),
            children: [
              Row(
                children: [
                  Text(
                    'Hi, there',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Avatar(initials: 'YO', size: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _BalanceSummary(owed: owed, owe: owe),
              if (attentionCount > 0) ...[
                const SizedBox(height: AppSpacing.lg),
                _AttentionRow(count: attentionCount),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              const _RecentActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.owed, required this.owe});

  final int owed;
  final int owe;

  @override
  Widget build(BuildContext context) {
    final net = owed - owe;
    final label = net > 0
        ? 'You are owed overall'
        : net < 0
        ? 'You owe overall'
        : 'All settled';
    final direction = net > 0
        ? MoneyDirection.owed
        : net < 0
        ? MoneyDirection.owe
        : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          MoneyText(
            amount: net.abs(),
            currency: 'INR',
            style: AppTypography.displayAmount,
            direction: direction,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Breakdown(
                  label: 'Owed to you',
                  amount: owed,
                  color: AppColors.owedText,
                ),
              ),
              Expanded(
                child: _Breakdown(
                  label: 'You owe',
                  amount: owe,
                  color: AppColors.oweText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        Money.format(amount, 'INR'),
        style: AppTypography.label.copyWith(color: color),
      ),
    ],
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.pendingTint,
      borderRadius: BorderRadius.circular(AppRadii.tile),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 20, color: AppColors.pendingText),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$count item${count == 1 ? '' : 's'} need attention',
            style: AppTypography.label.copyWith(color: AppColors.pendingText),
          ),
        ),
      ],
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Recent activity',
        style: AppTypography.title.copyWith(color: AppColors.textPrimary),
      ),
      const SizedBox(height: AppSpacing.md),
      ...MockData.activity
          .take(2)
          .map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          activity.batchName,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity.time,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}
