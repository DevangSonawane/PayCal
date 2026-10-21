import 'package:flutter/material.dart';
import 'package:paycal/core/config/app_config.dart';
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
import 'package:paycal/data/member_directory.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';

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

/// Expense entry flow: pick the crib, pick what kind, drop the amount —
/// added straight through, no chooser dialog in between.
///
/// [payeeId] records the expense as money sent to that person (they receive
/// the whole amount). [splitWithIds] splits equally among exactly those
/// member ids instead of the whole crib. [onSaved] fires after the expense
/// is added to the data.
Future<void> showQuickAdd(
  BuildContext context, {
  String? cribId,
  String? payeeId,
  List<String>? splitWithIds,
  VoidCallback? onSaved,
}) {
  return showAppBottomSheet(
    context: context,
    title: 'Add expense',
    builder: (_) => _QuickAddForm(
      initialCribId: cribId,
      payeeId: payeeId,
      initialSplitWithIds: splitWithIds,
      onSaved: onSaved,
    ),
  );
}

class _QuickAddForm extends StatefulWidget {
  const _QuickAddForm({
    this.initialCribId,
    this.payeeId,
    this.initialSplitWithIds,
    this.onSaved,
  });
  final String? initialCribId;
  final String? payeeId;
  final List<String>? initialSplitWithIds;
  final VoidCallback? onSaved;

  @override
  State<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends State<_QuickAddForm> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  String? _cribId;
  String? _type;

  Member? get payee {
    final id = widget.payeeId;
    if (id == null) return null;
    return MemberDirectory.memberById(id);
  }

  /// The cribs the signed-in member can add to.
  List<Crib> get _cribs => PayCalRepositories.instance.cribs.cachedCribs;

  /// The signed-in member.
  String get _meId => PayCalRepositories.instance.currentUserId;

  /// The members an expense of the selected crib is split between.
  ///
  /// An explicit split wins; otherwise every active member of the crib
  /// shares the expense. The list is empty when no crib is picked or when the
  /// crib has no active members — callers must cope with that instead of
  /// dividing by its length.
  List<String> get _splitIds {
    final crib = MemberDirectory.cribById(_cribId ?? '');
    if (crib == null) return const <String>[];
    return widget.initialSplitWithIds ?? [
      for (final m in crib.activeMembers) m.id,
    ];
  }

  @override
  void initState() {
    super.initState();
    final meId = PayCalRepositories.instance.currentUserId;
    final mine = [
      for (final crib in _cribs)
        if (crib.memberById(meId)?.isActive ?? false) crib,
    ];
    _cribId =
        widget.initialCribId ??
        (mine.isNotEmpty ? mine.first.id : (_cribs.isEmpty ? null : _cribs.first.id));
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final minor = Money.tryParseToMinor(_amount.text);
    if (minor == null || minor <= 0) {
      showAppToast(context, 'Pop in an amount first');
      return;
    }
    if (_type == null) {
      showAppToast(context, 'Pick what kind of expense this is');
      return;
    }
    final crib = MemberDirectory.cribById(_cribId ?? '');
    if (crib == null) {
      showAppToast(context, 'Pick a crib first');
      return;
    }
    final payee = this.payee;
    final splitIds = _splitIds;
    final Map<String, int> shares;
    if (payee != null) {
      shares = {payee.id: minor};
    } else {
      if (splitIds.isEmpty) {
        showAppToast(context, 'Nobody to split with — invite someone first');
        return;
      }
      try {
        shares = _equalShares(splitIds, minor);
      } on FinancialValidationException catch (error) {
        showAppToast(context, error.message);
        return;
      }
    }
    final desc = _desc.text.trim().isEmpty
        ? (payee == null ? '$_type expense' : 'Sent to ${payee.name}')
        : _desc.text.trim();
    try {
      await PayCalRepositories.instance.expenses.create(
        Expense(
          id: 'e${DateTime.now().millisecondsSinceEpoch}',
          cribId: crib.id,
          description: desc,
          totalMinor: minor,
          currency: crib.currency,
          payerId: _meId,
          shares: shares,
          date: DateTime.now(),
          category: _type!,
          createdById: _meId,
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) showAppToast(context, error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showQuirkyConfirm(
      context,
      payee == null
          ? 'All set — added to ${crib.name}'
          : 'Recorded for ${payee.name}',
    );
    widget.onSaved?.call();
  }

  Map<String, int> _equalShares(List<String> ids, int minor) =>
      FinancialLedger.equalSplit(
        totalMinor: minor,
        participantIds: ids,
        payerId: _meId,
      );

  @override
  Widget build(BuildContext context) {
    final crib = MemberDirectory.cribById(_cribId ?? '');
    final splitIds = _splitIds;
    final payeeNames = [for (final id in splitIds) MemberDirectory.nameFor(id)];
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
          'Which crib?',
          style: AppTypography.label.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_cribs.isEmpty)
          Text(
            'You have no cribs yet — create one to start splitting.',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final b in _cribs)
                StickerPill(
                  label: b.name,
                  selected: _cribId == b.id,
                  onTap: () => setState(() => _cribId = b.id),
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
          currency: crib?.currency ?? AppConfig.defaultCurrency,
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
    this.currency = 'INR',
  });
  final TextEditingController amount;
  final int ways;
  final bool isPayee;
  final String currency;

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
    // A crib without active members has nobody to split with. The divisor is
    // guarded, because `0 ~/ 0` throws an IntegerDivisionByZeroException.
    final ways = widget.ways;
    final per = ways > 0 ? minor ~/ ways : 0;
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
                        ? '${Money.format(minor, widget.currency)} goes to the payee'
                        : ways > 0
                              ? '${Money.format(per, widget.currency)} each · split $ways ways'
                              : 'Nobody to split with yet — invite someone first')
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
