import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/amount_field.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';

const _types = [
  'Food',
  'Groceries',
  'Rent',
  'Travel',
  'Bills',
  'Fun',
  'Subscriptions',
  'Other',
];

/// Expense entry flow: pick the batch, pick what kind, drop the amount —
/// added straight through, no chooser dialog in between.
///
/// [payeeId] records the expense as money sent to that person (they receive
/// the whole amount). [splitWithIds] splits equally among exactly those
/// member ids instead of the whole batch. [onSaved] fires after the expense
/// is added to the data.
Future<void> showQuickAdd(
  BuildContext context, {
  String? batchId,
  String? payeeId,
  List<String>? splitWithIds,
  VoidCallback? onSaved,
}) {
  return showAppBottomSheet(
    context: context,
    title: 'Add expense',
    builder: (_) => _QuickAddForm(
      initialBatchId: batchId,
      payeeId: payeeId,
      initialSplitWithIds: splitWithIds,
      onSaved: onSaved,
    ),
  );
}

class _QuickAddForm extends StatefulWidget {
  const _QuickAddForm({
    this.initialBatchId,
    this.payeeId,
    this.initialSplitWithIds,
    this.onSaved,
  });
  final String? initialBatchId;
  final String? payeeId;
  final List<String>? initialSplitWithIds;
  final VoidCallback? onSaved;

  @override
  State<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends State<_QuickAddForm> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String? _batchId;
  String? _type;

  Member? get payee {
    final id = widget.payeeId;
    if (id == null) return null;
    for (final b in MockData.batches) {
      for (final m in b.members) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _batchId = widget.initialBatchId ?? MockData.batches.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final minor = Money.tryParseToMinor(_amount.text);
    if (minor == null || minor <= 0) {
      showAppToast(context, 'Pop in an amount first');
      return;
    }
    if (_type == null) {
      showAppToast(context, 'Pick what kind of expense this is');
      return;
    }
    final batch = MockData.batches.firstWhere(
      (b) => b.id == _batchId,
      orElse: () => MockData.batches.first,
    );
    final payee = this.payee;
    final splitIds =
        widget.initialSplitWithIds ?? [for (final m in batch.members) m.id];
    final shares = payee != null
        ? {payee.id: minor}
        : _equalShares(splitIds, minor);
    final desc = _desc.text.trim().isEmpty
        ? (payee == null ? '$_type expense' : 'Sent to ${payee.name}')
        : _desc.text.trim();
    MockData.expenses.add(
      Expense(
        id: 'e${DateTime.now().millisecondsSinceEpoch}',
        batchId: batch.id,
        description: desc,
        totalMinor: minor,
        currency: batch.currency,
        payerId: MockData.meId,
        shares: shares,
        date: DateTime.now(),
        category: _type!,
      ),
    );
    Navigator.of(context).pop();
    showQuirkyConfirm(
      context,
      payee == null
          ? 'All set — added to ${batch.name}'
          : 'Recorded for ${payee.name}',
    );
    widget.onSaved?.call();
  }

  Map<String, int> _equalShares(List<String> ids, int minor) {
    final n = ids.length;
    final per = minor ~/ n;
    var remainder = minor - per * n;
    return {for (final id in ids) id: per + ((remainder-- > 0) ? 1 : 0)};
  }

  @override
  Widget build(BuildContext context) {
    final batch = MockData.batches.firstWhere(
      (b) => b.id == _batchId,
      orElse: () => MockData.batches.first,
    );
    final splitIds =
        widget.initialSplitWithIds ?? [for (final m in batch.members) m.id];
    final payeeNames = [for (final id in splitIds) MockData.memberName(id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (payee != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.south_west_rounded,
                  color: AppPalette.current.ink,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Recording money sent to ${payee!.name} — they get the full amount.',
                    style: AppTypography.label.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (widget.initialSplitWithIds != null &&
            widget.initialSplitWithIds!.length > 2)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.call_split_outlined,
                  color: AppPalette.current.ink,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Splitting equally with ${payeeNames.length} people.',
                    style: AppTypography.label.copyWith(
                      color: AppPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Which batch?',
          style: AppTypography.label.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final b in MockData.batches)
              StickerPill(
                label: b.name,
                selected: _batchId == b.id,
                onTap: () => setState(() => _batchId = b.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'What type?',
          style: AppTypography.label.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in _types)
              StickerPill(
                label: t,
                selected: _type == t,
                showCheck: true,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Amount',
          style: AppTypography.caption.copyWith(
            color: AppPalette.current.grey,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AmountField(
          currencySymbol: AppSettings.instance.currencySymbol,
          controller: _amount,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'What was it for?',
          hint: 'Dinner, rent, taxi…',
          controller: _desc,
        ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(height: AppSpacing.md),
        _Preview(
          amount: _amount,
          ways: payee == null ? splitIds.length : 1,
          isPayee: payee != null,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(label: 'Add expense', onPressed: _submit),
      ],
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({
    required this.amount,
    required this.ways,
    this.isPayee = false,
  });
  final TextEditingController amount;
  final int ways;
  final bool isPayee;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  void initState() {
    super.initState();
    widget.amount.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.amount.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minor = Money.tryParseToMinor(widget.amount.text) ?? 0;
    final per = minor ~/ widget.ways;
    final active = minor > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: active ? AppPalette.current.lime : AppPalette.current.chip,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppPalette.current.ink : AppPalette.current.hairline,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate_outlined,
            color: active ? AppPalette.current.ink : AppPalette.current.grey,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              active
                  ? (widget.isPayee
                        ? '${Money.format(minor, 'INR')} goes to the payee'
                        : '${Money.format(per, 'INR')} each · split ${widget.ways} ways')
                  : 'Enter an amount to preview shares',
              style: AppTypography.label.copyWith(
                color: active
                    ? AppPalette.current.ink
                    : AppPalette.current.grey,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
