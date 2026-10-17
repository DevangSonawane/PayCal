import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/empty_state.dart';
import 'package:paycal/core/widgets/expense_icon.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/skeleton.dart';
import 'package:paycal/core/widgets/status_chip.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () => mounted ? setState(() => _loading = false) : null);
  }

  int _netForBatch(Batch b) {
    final exps = MockData.expenses.where((e) => e.batchId == b.id).toList();
    final inputs = exps.map((e) => ExpenseInput(totalMinor: e.totalMinor, payerId: e.payerId, shares: e.shares)).toList();
    final nets = BalanceEngine.nets(inputs, b.members.map((m) => m.id).toList());
    return nets[MockData.meId] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Hi, there', style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {},
                      child: const Avatar(initials: 'YO', size: 40),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_loading) ...[
                  const Skeleton(width: 200, height: 48),
                  const SizedBox(height: AppSpacing.sm),
                  const Skeleton(width: 140, height: 16),
                ] else
                  _hero(),
                const SizedBox(height: AppSpacing.xxl),
                _needsAttention(),
                const SizedBox(height: AppSpacing.xxl),
                _batches(),
                const SizedBox(height: AppSpacing.xxl),
                _recent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    // One card per currency — mock has INR only.
    var owed = 0;
    var owe = 0;
    for (final b in MockData.batches) {
      final n = _netForBatch(b);
      if (n > 0) {
        owed += n;
      } else {
        owe += -n;
      }
    }
    final net = owed - owe;
    final label = net > 0 ? 'You are owed' : (net < 0 ? 'You owe' : 'All settled');
    final dir = net > 0 ? MoneyDirection.owed : (net < 0 ? MoneyDirection.owe : null);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          MoneyText(amount: net.abs(), currency: 'INR', style: AppTypography.displayAmount, direction: dir),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.owedTint, borderRadius: BorderRadius.circular(AppRadii.chipPill)),
                child: Text('Owed to you ${Money.format(owed, 'INR')}', style: AppTypography.caption.copyWith(color: AppColors.owedText)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.oweTint, borderRadius: BorderRadius.circular(AppRadii.chipPill)),
                child: Text('You owe ${Money.format(owe, 'INR')}', style: AppTypography.caption.copyWith(color: AppColors.oweText)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _needsAttention() {
    final items = MockData.expenses.where((e) => e.unpaid || e.disputed).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Needs attention', style: AppTypography.title.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.md),
        ...items.map((e) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ExpenseIcon(category: e.category),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.description, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                        Text('Paid by ${MockData.memberName(e.payerId)}', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  StatusChip(label: e.disputed ? 'Disputed' : 'Unpaid', status: e.disputed ? ChipStatus.disputed : ChipStatus.pending),
                ],
              ),
            )),
      ],
    );
  }

  Widget _batches() {
    if (MockData.batches.isEmpty) {
      return EmptyState(title: 'Add your first expense', body: 'Create a batch and add what you spent.', actionLabel: 'Add expense', onAction: () => showQuickAdd(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your batches', style: AppTypography.title.copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.md),
        ...MockData.batches.map((b) {
          final net = _netForBatch(b);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BatchDetailScreen(batch: b))),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadii.card)),
              child: Row(
                children: [
                  AvatarStack(initials: b.members.map((m) => m.initials).toList()),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                        Text('${b.members.length} members', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  MoneyText(amount: net.abs(), currency: b.currency, direction: net > 0 ? MoneyDirection.owed : (net < 0 ? MoneyDirection.owe : null)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _recent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent activity', style: AppTypography.title.copyWith(color: AppColors.textPrimary)),
            const Spacer(),
            Text('See all', style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...MockData.activity.take(5).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title, style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary)),
                        Text(a.subtitle, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(a.time, style: AppTypography.caption.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            )),
      ],
    );
  }
}
