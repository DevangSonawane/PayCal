import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/amount_field.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/core/widgets/status_chip.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/expenses/split_share_editor.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expense, this.onDone});
  final Expense expense;

  /// Fires after an edit or delete so parents can refresh their local state.
  final VoidCallback? onDone;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late Expense expense = widget.expense;

  Batch get batch => MockData.batches.firstWhere(
    (b) => b.id == expense.batchId,
    orElse: () => MockData.batches.first,
  );

  void _replace(Expense next) {
    final i = MockData.expenses.indexOf(widget.expense);
    if (i >= 0) {
      MockData.expenses[i] = next;
    }
    setState(() => expense = next);
    widget.onDone?.call();
  }

  Future<void> _flagProblem() async {
    if (expense.disputed) {
      showAppToast(context, 'Already flagged — the payer has been notified');
      return;
    }
    final ok = await showConfirmSheet(
      context: context,
      title: 'Flag a problem?',
      body:
          'Marks this as disputed so ${MockData.memberName(expense.payerId)} knows something is off.',
      confirmLabel: 'Flag it',
    );
    if (ok == true && mounted) {
      _replace(
        Expense(
          id: expense.id,
          batchId: expense.batchId,
          description: expense.description,
          totalMinor: expense.totalMinor,
          currency: expense.currency,
          payerId: expense.payerId,
          shares: expense.shares,
          date: expense.date,
          category: expense.category,
          disputed: true,
          unpaid: expense.unpaid,
        ),
      );
      showAppToast(context, 'Flagged — the payer has been notified');
    }
  }

  Future<void> _edit() async {
    final amount = TextEditingController(
      text: Money.format(expense.totalMinor, expense.currency),
    );
    final desc = TextEditingController(text: expense.description);
    var category = expense.category;
    Map<String, int>? shares;
    var splitComplete = false;

    await showPopCard<bool>(
      context: context,
      title: 'Edit expense',
      builder: (popContext) => StatefulBuilder(
        builder: (dialogContext, setPopState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountField(
              currencySymbol: AppSettings.instance.currencySymbol,
              controller: amount,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'What was it for?', controller: desc),
            const SizedBox(height: AppSpacing.md),
            _CategoryPicker(
              categories: batch.categories,
              selected: category,
              onPicked: (v) => setPopState(() => category = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Split',
              style: AppTypography.label.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SplitShareEditor(
              members: batch.members,
              amountController: amount,
              currency: expense.currency,
              initialShares: expense.shares,
              onChanged: (s, ok) {
                shares = s;
                splitComplete = ok;
              },
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: 'Save changes',
        onPressed: () {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          if (shares == null || !splitComplete) {
            showAppToast(
              context,
              'The split has to add up to the whole amount',
            );
            return;
          }
          Navigator.of(context).pop();
          _replace(
            Expense(
              id: expense.id,
              batchId: expense.batchId,
              description: desc.text.trim().isEmpty
                  ? expense.description
                  : desc.text.trim(),
              totalMinor: minor,
              currency: expense.currency,
              payerId: expense.payerId,
              shares: shares!,
              date: expense.date,
              category: category,
              disputed: expense.disputed,
              unpaid: expense.unpaid,
            ),
          );
          widget.onDone?.call();
          showAppToast(context, 'Saved — expense updated');
        },
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete expense?',
      body: 'This removes it for everyone in the batch.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok == true && mounted) {
      MockData.expenses.remove(widget.expense);
      Navigator.of(context).pop();
      widget.onDone?.call();
      showAppToast(context, 'Gone — expense deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final equal =
        expense.shares.entries.map((e) => e.value).toSet().length == 1;
    return Scaffold(
      backgroundColor: AppPalette.current.bg,
      appBar: AppBar(
        backgroundColor: AppPalette.current.bg,
        elevation: 0,
        leading: const BackButton(color: AppPalette.current.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            MediaQuery.of(context).padding.bottom + AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expense.disputed)
                const StatusChip(label: 'Disputed', status: ChipStatus.disputed)
              else if (expense.unpaid)
                const StatusChip(label: 'Unpaid', status: ChipStatus.pending),
              const SizedBox(height: AppSpacing.md),
              MoneyText(
                amount: expense.totalMinor,
                currency: expense.currency,
                style: AppTypography.displayAmount,
              ),
              Text(
                expense.description,
                style: AppTypography.headline.copyWith(
                  color: AppPalette.current.text,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _row(
                'Date',
                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
              ),
              _row('Paid by', MockData.memberName(expense.payerId)),
              _row('Category', expense.category),
              _row(
                'Split',
                equal
                    ? 'Equally between ${expense.shares.length}'
                    : 'Custom shares',
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final entry in expense.shares.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _row2(
                    entry.key == MockData.meId
                        ? 'You'
                        : MockData.memberName(entry.key),
                    Money.format(entry.value, expense.currency),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(label: 'Flag a problem', onPressed: _flagProblem),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(label: 'Edit', onPressed: _edit),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SecondaryButton(label: 'Delete', onPressed: _delete),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'History',
                style: AppTypography.titleSmall.copyWith(
                  color: AppPalette.current.text,
                ),
              ),
              Text(
                expense.disputed
                    ? 'A problem was flagged on this expense'
                    : 'One expense, ${expense.shares.length} people in the split',
                style: AppTypography.body.copyWith(
                  color: AppPalette.current.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => _row2(k, v);

  Widget _row2(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.current.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: AppTypography.body.copyWith(
                color: AppPalette.current.textSecondary,
              ),
            ),
          ),
          Text(
            v,
            style: AppTypography.titleSmall.copyWith(
              color: AppPalette.current.text,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onPicked,
  });
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final picked = await showPopCard<String>(
        context: context,
        title: 'Category',
        builder: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in categories)
              OptionTile(
                title: c,
                selected: c == selected,
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      );
      if (picked != null) onPicked(picked);
    },
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Category · $selected',
              style: AppTypography.label.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.expand_more, color: AppPalette.current.ink),
        ],
      ),
    ),
  );
}
