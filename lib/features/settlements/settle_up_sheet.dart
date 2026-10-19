import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';

/// Who owes whom, resolved greedily into the fewest person-to-person
/// transfers, so the batch can be marked fully square.
class SettlementTransfer {
  SettlementTransfer({
    required this.fromId,
    required this.toId,
    required this.amountMinor,
  });
  final String fromId;
  final String toId;
  final int amountMinor;
}

List<SettlementTransfer> transfersForBatch(Batch batch) {
  final balances = <String, int>{for (final m in batch.members) m.id: 0};
  final batchExpenses = MockData.expenses.where((e) => e.batchId == batch.id);
  for (final e in batchExpenses) {
    final paid = balances[e.payerId] ?? 0;
    balances[e.payerId] = paid + e.totalMinor;
    e.shares.forEach((mid, share) {
      if (balances.containsKey(mid)) {
        balances[mid] = (balances[mid] ?? 0) - share;
      }
    });
  }
  // Greedy: smallest debtor pairs against the largest creditor each round.
  final debtors = <int, String>{}; // -balance -> id
  final creditors = <int, String>{}; // balance -> id
  balances.forEach((id, net) {
    if (net < 0) debtors[-net] = id;
    if (net > 0) creditors[net] = id;
  });
  final transfers = <SettlementTransfer>[];
  var guard = 0;
  while (debtors.isNotEmpty && creditors.isNotEmpty && guard++ < 200) {
    final debtorKey = debtors.keys.reduce((a, b) => a > b ? a : b);
    final debtor = debtors.remove(debtorKey)!;
    final creditorKey = creditors.keys.reduce((a, b) => a > b ? a : b);
    final creditor = creditors.remove(creditorKey)!;
    final amount = debtorKey < creditorKey ? debtorKey : creditorKey;
    transfers.add(
      SettlementTransfer(fromId: debtor, toId: creditor, amountMinor: amount),
    );
    if (debtorKey - amount > 0) debtors[debtorKey - amount] = debtor;
    if (creditorKey - amount > 0) creditors[creditorKey - amount] = creditor;
  }
  return transfers;
}

/// Batch-wide settle-up: shows the minimum transfers and, on confirm, records
/// each as an expense (payer = person transferring, full share to recipient).
Future<void> showSettleUp(
  BuildContext context,
  Batch batch, {
  VoidCallback? onRecorded,
}) {
  final transfers = transfersForBatch(batch);
  return showPopCard<void>(
    context: context,
    title: 'Settle up',
    builder: (_) => transfers.isEmpty
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppPalette.current.lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppPalette.current.ink, width: 2),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: AppPalette.current.ink,
                    size: 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'All square!',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppPalette.current.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Nothing to settle in ${batch.name}.',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The fewest moves to make ${batch.name} square:',
                style: AppTypography.caption.copyWith(
                  color: AppPalette.current.grey,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final t in transfers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppPalette.current.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${MockData.memberName(t.fromId)} pays',
                                  textAlign: TextAlign.right,
                                  style: AppTypography.label.copyWith(
                                    color: AppPalette.current.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Text(
                                  Money.format(t.amountMinor, batch.currency),
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppPalette.current.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                'to ${MockData.memberName(t.toId)}',
                                style: AppTypography.label.copyWith(
                                  color: AppPalette.current.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Recording each transfer as a square-up expense.',
                style: AppTypography.caption.copyWith(
                  color: AppPalette.current.grey,
                ),
              ),
            ],
          ),
    footer: transfers.isEmpty
        ? null
        : PrimaryButton(
            label: 'Record transfers',
            onPressed: () {
              for (final t in transfers) {
                MockData.expenses.add(
                  Expense(
                    id: 'e${DateTime.now().millisecondsSinceEpoch}-sq-${t.toId}',
                    batchId: batch.id,
                    description: 'Square-up to ${MockData.memberName(t.toId)}',
                    totalMinor: t.amountMinor,
                    currency: batch.currency,
                    payerId: t.fromId,
                    shares: {t.toId: t.amountMinor},
                    date: DateTime.now(),
                    category: 'other',
                  ),
                );
              }
              Navigator.of(context).pop();
              onRecorded?.call();
              showQuirkyConfirm(context, 'All square!');
            },
          ),
  );
}
