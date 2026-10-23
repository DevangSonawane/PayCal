import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/member_directory.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

/// Who owes whom, resolved greedily into the fewest person-to-person
/// transfers, so the crib can be marked fully square.
List<SettlementTransfer> transfersForCrib(Crib crib) {
  return FinancialLedger.suggestedTransfers(
    crib: crib,
    expenses: PayCalRepositories.instance.expenses.cachedExpenses.where(
      (expense) => expense.cribId == crib.id,
    ),
    settlements: PayCalRepositories.instance.settlements.cachedSettlements
        .where((settlement) => settlement.cribId == crib.id),
  );
}

/// Crib-wide settle-up records self-managed settlement records. It does not
/// create fake expenses, so spending totals stay accurate.
///
/// Only the signed-in member can record their own transfer. Somebody else's
/// transfer stays a request until that member records it.
Future<void> showSettleUp(
  BuildContext context,
  Crib crib, {
  VoidCallback? onRecorded,
}) {
  final transfers = transfersForCrib(crib);
  final meId = PayCalRepositories.instance.currentUserId;
  final mine = [
    for (final t in transfers)
      if (t.fromId == meId) t,
  ];
  final theirs = [
    for (final t in transfers)
      if (t.fromId != meId) t,
  ];
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
                  'Nothing to settle in ${crib.name}.',
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
                'The fewest moves to make ${crib.name} square:',
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
                                  '${MemberDirectory.nameFor(t.fromId)} pays',
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
                                  Money.format(t.amountMinor, crib.currency),
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppPalette.current.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                'to ${MemberDirectory.nameFor(t.toId)}',
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
              if (mine.isEmpty)
                Text(
                  'Nothing for you to record here. Ask the others to settle '
                  'their own transfers.',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.grey,
                  ),
                )
              else
                Text(
                  'Recording your transfer as a self-managed settlement.',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
              if (theirs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${theirs.length} transfer${theirs.length == 1 ? '' : 's'} '
                  'belong to other members. They record those themselves.',
                  style: AppTypography.caption.copyWith(
                    color: AppPalette.current.grey,
                  ),
                ),
              ],
            ],
          ),
    footer: mine.isEmpty
        ? null
        : _RecordTransfersButton(
            transfers: mine,
            crib: crib,
            onRecorded: onRecorded,
            onError: (error) {
              if (context.mounted) showAppToast(context, error.message);
            },
          ),
  );
}

/// Records the transfers of the signed-in member.
///
/// The button ignores a second tap while it is recording, because every tap
/// builds a new request id and would otherwise record the transfer twice.
class _RecordTransfersButton extends StatefulWidget {
  const _RecordTransfersButton({
    required this.transfers,
    required this.crib,
    required this.onRecorded,
    required this.onError,
  });

  final List<SettlementTransfer> transfers;
  final Crib crib;
  final VoidCallback? onRecorded;
  final void Function(RepositoryException error) onError;

  @override
  State<_RecordTransfersButton> createState() =>
      _RecordTransfersButtonState();
}

class _RecordTransfersButtonState extends State<_RecordTransfersButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: _busy
            ? 'Recording…'
            : 'Record my transfer${widget.transfers.length == 1 ? '' : 's'}',
        loading: _busy,
        onPressed: _busy ? null : _record,
      );

  Future<void> _record() async {
    // One key per request: a replay of the same request returns the
    // original settlement, a later request records a new transfer.
    final requestId = DateTime.now().microsecondsSinceEpoch;
    setState(() => _busy = true);
    try {
      for (final t in widget.transfers) {
        await PayCalRepositories.instance.settlements.create(
          Settlement(
            id: 'e${DateTime.now().millisecondsSinceEpoch}-sq-${t.toId}',
            cribId: widget.crib.id,
            currency: widget.crib.currency,
            fromMemberId: t.fromId,
            toMemberId: t.toId,
            amountMinor: t.amountMinor,
            status: SettlementStatus.selfManaged,
            createdAt: DateTime.now(),
            idempotencyKey:
                '${widget.crib.id}:${t.fromId}:${t.toId}:${t.amountMinor}:$requestId',
          ),
        );
      }
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onError(error);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onRecorded?.call();
    showQuirkyConfirm(context, 'All square!');
  }
}
