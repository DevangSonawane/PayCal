import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paycal/core/export/export_ledger.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/amount_field.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/member_directory.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';
import 'package:paycal/domain/recurring_scheduler.dart';
import 'package:paycal/features/expenses/expense_detail_screen.dart';
import 'package:paycal/features/expenses/split_share_editor.dart';
import 'package:paycal/features/cribs/invite_link_sheet.dart';
import 'package:paycal/features/settlements/settle_up_sheet.dart';

class _DPalette {
  static AppPalette get current => AppPalette.current;
}

/// A crib reads as a shared payment conversation: payments from the current
/// user are on the right and payments from everyone else are on the left.
class CribDetailScreen extends StatefulWidget {
  const CribDetailScreen({super.key, required this.crib});

  final Crib crib;

  @override
  State<CribDetailScreen> createState() => _CribDetailScreenState();
}

class _CribDetailScreenState extends State<CribDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_postDueRecurringPayments());
  }

  int _net(List<Expense> expenses) =>
      FinancialLedger.balances(
        crib: _crib,
        expenses: expenses,
        settlements: PayCalRepositories.instance.settlements.cachedSettlements
            .where((settlement) => settlement.cribId == _crib.id),
      )[PayCalRepositories.instance.currentUserId] ??
      0;

  /// The signed-in member.
  String get _meId => PayCalRepositories.instance.currentUserId;

  /// Whether the signed-in member owns the crib.
  ///
  /// The repositories enforce this on every owner-only operation. The screen
  /// only uses it to show the owner actions to the owner, so a member does
  /// not tap a button that is bound to fail.
  bool get _isOwner => _crib.ownerId == _meId;

  /// The crib as the repositories know it. Membership changes made somewhere
  /// else show up here without a restart.
  Crib get _crib =>
      MemberDirectory.cribById(_cribId) ?? widget.crib;

  /// The id of the crib this screen shows.
  String get _cribId => widget.crib.id;

  /// Members that can still take part in the crib.
  List<Member> get _activeMembers => _crib.activeMembers;

  @override
  Widget build(BuildContext context) {
    final expenses =
        PayCalRepositories.instance.expenses.cachedExpenses
            .where((expense) => expense.cribId == _crib.id)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final net = _net(expenses);

    return Scaffold(
      backgroundColor: _DPalette.current.page,
      body: CustomPaint(
        painter: _StripePainter(),
        child: SizedBox.expand(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  crib: _crib,
                  onBack: () => Navigator.of(context).maybePop(),
                  onDetails: () => _showGroupDetails(context, _crib),
                  onSettleUp: () => showSettleUp(
                    context,
                    _crib,
                    onRecorded: () => setState(() {}),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      14,
                      24,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    children: [
                      _HeroCard(crib: _crib, net: net),
                      SizedBox(height: 22),
                      Row(
                        children: [
                          Text(
                            'Payments',
                            style: AppTypography.title.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _DPalette.current.ink,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${expenses.length} total',
                            style: AppTypography.caption.copyWith(
                              color: _DPalette.current.grey,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      if (expenses.isEmpty)
                        _EmptyPayments()
                      else
                        for (var i = 0; i < expenses.length; i++) ...[
                          if (i == 0 ||
                              !_isSameDay(
                                expenses[i - 1].date,
                                expenses[i].date,
                              ))
                            _DateLabel(date: expenses[i].date),
                          _PaymentBubble(
                            crib: _crib,
                            expense: expenses[i],
                            onExpenseChanged: () => setState(() {}),
                          ),
                          if (i != expenses.length - 1)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                height: 1,
                                color: _DPalette.current.hairline,
                              ),
                            ),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddActions,
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: StadiumBorder(),
        icon: Icon(Icons.add),
        label: Text(
          'Add',
          style: AppTypography.label.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  /// An amount as a plain number, so the amount field can parse it back.
  static String _plainAmount(int minorUnits) {
    final whole = minorUnits ~/ 100;
    final fraction = (minorUnits % 100).toString().padLeft(2, '0');
    return '$whole.$fraction';
  }

  /// Lets the owner choose the member who pays a recurring transfer.
  ///
  /// A paused schedule waits for an active member, and a running schedule can
  /// hand the paying over to another member.
  void _showAssignPayerSheet(RecurringPayment schedule) {
    final members = _crib.activeMembers;
    if (members.isEmpty) {
      showAppToast(context, 'This crib has no active members left');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _DPalette.current.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who pays this transfer?',
                style: AppTypography.headline.copyWith(
                  color: _DPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                schedule.isPaused
                    ? 'The schedule is paused. Pick the member who takes over.'
                    : 'The next occurrences are paid by the member you pick.',
                style: AppTypography.caption.copyWith(
                  color: _DPalette.current.grey,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              for (final member in members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    member.id == _meId ? 'You' : member.name,
                    style: AppTypography.label.copyWith(
                      color: _DPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () async {
                    try {
                      await PayCalRepositories.instance.recurring
                          .assignPayer(schedule.id, member.id);
                    } on RepositoryException catch (error) {
                      if (sheetContext.mounted) {
                        showAppToast(sheetContext, error.message);
                      }
                      return;
                    }
                    if (!mounted || !sheetContext.mounted) return;
                    setState(() {});
                    Navigator.of(sheetContext).pop();
                    showAppToast(
                      context,
                      member.id == _meId
                          ? 'You are paying this transfer'
                          : '${member.name} is paying this transfer',
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The next due date of a schedule, in its own timezone.
  String _nextDueLabel(RecurringPayment schedule) {
    if (schedule.isPaused) return 'paused';
    try {
      final due = RecurringScheduler.nextDueDateAfter(
        schedule: schedule,
        now: DateTime.now(),
      );
      return '${due.day}/${due.month}';
    } on RecurrenceException {
      return '-';
    }
  }

  void _showGroupDetails(BuildContext context, Crib crib) {
    final recurring = PayCalRepositories.instance.recurring.cachedSchedules
        .where((r) => r.cribId == crib.id && r.active)
        .toList()
        .reversed
        .toList();
    final members = crib.activeMembers;
    showAppBottomSheet<void>(
      context: context,
      title: crib.name,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${members.length} members',
            style: AppTypography.body.copyWith(color: _DPalette.current.grey),
          ),
          SizedBox(height: AppSpacing.lg),
          ...members.map(
            (member) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Avatar(initials: member.initials, size: 38),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      member.id == _meId ? 'You' : member.name,
                      style: AppTypography.label.copyWith(
                        color: _DPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (member.isAdmin)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _DPalette.current.lime,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _DPalette.current.ink),
                      ),
                      child: Text(
                        'Owner',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          OptionTile(
            title: 'Invite someone',
            support: _isOwner
                ? 'Get a private link that expires in 7 days'
                : 'Only the Crib Owner can invite new people',
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _DPalette.current.lime,
                shape: BoxShape.circle,
                border: Border.all(color: _DPalette.current.ink, width: 1.5),
              ),
              child: Icon(
                Icons.link_rounded,
                size: 18,
                color: _DPalette.current.ink,
              ),
            ),
            onTap: _isOwner
                ? () {
                    Navigator.of(sheetContext).pop();
                    showInviteLinkSheet(context, crib: crib);
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          OptionTile(
            title: 'Export history',
            support: 'Save the ledger of this crib as a PDF',
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _DPalette.current.card,
                shape: BoxShape.circle,
                border: Border.all(color: _DPalette.current.ink, width: 1.5),
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: _DPalette.current.ink,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _exportHistory(crib);
            },
          ),
          if (_isOwner) ...[
            const SizedBox(height: AppSpacing.sm),
            OptionTile(
              title: 'Hand over this crib',
              support: _activeMembers.any((member) => member.id != _meId)
                  ? 'Another member becomes the Crib Owner'
                  : 'Invite somebody first',
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _DPalette.current.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _DPalette.current.ink, width: 1.5),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: _DPalette.current.ink,
                ),
              ),
              onTap: _activeMembers.any((member) => member.id != _meId)
                  ? () {
                      Navigator.of(sheetContext).pop();
                      _showTransferOwnershipSheet(crib);
                    }
                  : null,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            OptionTile(
              title: 'Leave this crib',
              support: 'You stop taking part, your history stays',
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _DPalette.current.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _DPalette.current.ink, width: 1.5),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: _DPalette.current.ink,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _leaveCrib(crib);
              },
            ),
          ],
          if (recurring.isNotEmpty) ...[
            SizedBox(height: AppSpacing.lg),
            Text(
              'Recurring transfers',
              style: AppTypography.label.copyWith(
                color: _DPalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            for (final r in recurring)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppPalette.current.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _DPalette.current.ink,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        color: _DPalette.current.ink,
                        size: 20,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.description} → ${MemberDirectory.nameFor(r.recipientId)}',
                              style: AppTypography.label.copyWith(
                                color: _DPalette.current.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${Money.format(r.amountMinor, r.currency)} · every ${r.frequency == RecurringFrequency.monthly ? 'month' : 'year'} · next ${_nextDueLabel(r)}',
                              style: AppTypography.caption.copyWith(
                                color: _DPalette.current.grey,
                              ),
                            ),
                            Text(
                              r.isPaused
                                  ? 'Paused — waiting for a payer'
                                  : 'Paid by ${MemberDirectory.nameFor(r.payerId!)}',
                              style: AppTypography.caption.copyWith(
                                color: r.isPaused
                                    ? _DPalette.current.grey
                                    : _DPalette.current.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isOwner)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _showRecurringTransferSheet(existing: r);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _DPalette.current.card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _DPalette.current.ink,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: _DPalette.current.ink,
                            ),
                          ),
                        ),
                      if (_isOwner) SizedBox(width: AppSpacing.sm),
                      if (_isOwner)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _showAssignPayerSheet(r);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _DPalette.current.card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _DPalette.current.ink,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.person_pin_circle_outlined,
                              size: 18,
                              color: _DPalette.current.ink,
                            ),
                          ),
                        ),
                      if (_isOwner) SizedBox(width: AppSpacing.sm),
                      if (_isOwner)
                        GestureDetector(
                          onTap: () async {
                            try {
                              await PayCalRepositories.instance.recurring.cancel(
                                r.id,
                              );
                          } on RepositoryException catch (error) {
                            if (sheetContext.mounted) {
                              showAppToast(sheetContext, error.message);
                            }
                            return;
                          }
                          if (!mounted || !sheetContext.mounted) return;
                          setState(() {});
                          showAppToast(
                            sheetContext,
                            'Recurring transfer cancelled',
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppPalette.current.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _DPalette.current.ink,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: _DPalette.current.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Writes the ledger of the crib into a PDF and opens the share sheet.
  Future<void> _exportHistory(Crib crib) async {
    try {
      await shareCribHistory(crib);
    } catch (error) {
      logExportFailure(error);
      if (!mounted) return;
      showAppToast(context, 'Could not export the history of ${crib.name}');
    }
  }

  /// Hands the crib over to another member of the crib.
  Future<void> _showTransferOwnershipSheet(Crib crib) async {
    final candidates = crib.activeMembers
        .where((member) => member.id != _meId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      showAppToast(context, 'Invite somebody first');
      return;
    }
    Member? chosen;
    await showAppBottomSheet<void>(
      context: context,
      title: 'Hand over ${crib.name}',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The new owner can invite people, change the crib and delete it. '
            'You stay a member of the crib.',
            style: AppTypography.caption.copyWith(
              color: _DPalette.current.grey,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final member in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                title: member.name,
                support: 'Member of ${crib.name}',
                onTap: () {
                  chosen = member;
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
        ],
      ),
    );
    final newOwner = chosen;
    if (newOwner == null || !mounted) return;
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Hand over ${crib.name}?',
      body: '${newOwner.name} becomes the Crib Owner of ${crib.name}. '
          'You stay a member and keep your own history.',
      confirmLabel: 'Hand it over',
    );
    if (confirmed != true) return;
    try {
      await PayCalRepositories.instance.cribs.transferOwnership(
        cribId: crib.id,
        newOwnerId: newOwner.id,
      );
    } on RepositoryException catch (error) {
      if (mounted) showAppToast(context, error.message);
      return;
    }
    if (!mounted) return;
    setState(() {});
    showAppToast(context, '${newOwner.name} is the new Crib Owner');
  }

  /// Leaves the crib.
  ///
  /// The member keeps their history and their share of what was already
  /// spent, but is never charged again.
  Future<void> _leaveCrib(Crib crib) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Leave ${crib.name}?',
      body: 'You stop taking part in ${crib.name}. What you already paid for '
          'and what you still owe stay in the history. The owner can invite '
          'you back later.',
      confirmLabel: 'Leave the crib',
      destructive: true,
    );
    if (confirmed != true) return;
    try {
      await PayCalRepositories.instance.cribs.leave(crib.id);
    } on RepositoryException catch (error) {
      if (mounted) showAppToast(context, error.message);
      return;
    }
    if (!mounted) return;
    showAppToast(context, 'You left ${crib.name}');
    Navigator.of(context).pop();
  }

  void _showAddActions() {    _showFormDialog(
      title: 'Add payment',
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionOption(
            icon: Icons.payments_outlined,
            title: 'Add money',
            subtitle: 'Record money paid to someone',
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showAddMoneySheet();
            },
          ),
          SizedBox(height: AppSpacing.md),
          _ActionOption(
            icon: Icons.receipt_long_outlined,
            title: 'Add expense',
            subtitle: 'Record something you paid for',
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showExpenseSheet(splitEqually: false);
            },
          ),
          SizedBox(height: AppSpacing.md),
          _ActionOption(
            icon: Icons.call_split_outlined,
            title: 'Split bill',
            subtitle: 'Divide a cost equally with the group',
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showExpenseSheet(splitEqually: true);
            },
          ),
          if (_isOwner) SizedBox(height: AppSpacing.md),
          if (_isOwner)
            _ActionOption(
              icon: Icons.autorenew_rounded,
              title: 'Set up recurring transfer',
              subtitle: 'Send money to a member on a schedule',
              onTap: () {
                Navigator.of(dialogContext).pop();
                _showRecurringTransferSheet();
              },
            ),
        ],
      ),
    );
  }

  /// Themed pop-up dialog (scale+fade "pop" instead of a bottom sheet).
  void _showFormDialog({
    required String title,
    required WidgetBuilder builder,
    Widget? footer,
  }) {
    showPopCard<void>(
      context: context,
      title: title,
      builder: builder,
      footer: footer,
    );
  }

  void _showAddMoneySheet() {
    final amount = TextEditingController();
    final recipients = _activeMembers
        .where((member) => member.id != _meId)
        .toList();
    if (recipients.isEmpty) {
      showAppToast(context, 'Add someone to the crib first');
      return;
    }
    var recipientId = recipients.first.id;
    _showFormDialog(
      title: 'Add money',
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetLabel('Amount'),
            AmountField(
              currencySymbol: AppSettings.instance.currencySymbol,
              controller: amount,
              autofocus: false,
            ),
            SizedBox(height: AppSpacing.lg),
            _sheetLabel('Paid to'),
            _SelectField<String>(
              value: recipientId,
              options: {for (final member in recipients) member.id: member.name},
              dialogTitle: 'Paid to',
              onChanged: (value) => setSheetState(() => recipientId = value),
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: 'Add money',
        onPressed: () async {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          final recipient = _activeMembers.firstWhere(
            (member) => member.id == recipientId,
          );
          final added = await _addEntry(
            description: 'Money to ${recipient.name}',
            amount: minor,
            shares: {_meId: minor},
            category: 'other',
          );
          if (!added) return;
          if (!mounted) return;
          Navigator.of(context).pop();
          showQuirkyConfirm(context, 'All set — money added!');
        },
      ),
    );
  }

  void _showExpenseSheet({required bool splitEqually}) {
    final amount = TextEditingController();
    final description = TextEditingController();
    var category = _crib.categories.first;
    Map<String, int>? shares;
    var splitComplete = false;
    _showFormDialog(
      title: splitEqually ? 'Split bill' : 'Add expense',
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetLabel('Amount'),
            AmountField(
              currencySymbol: AppSettings.instance.currencySymbol,
              controller: amount,
              autofocus: false,
            ),
            SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'What was it for?',
              hint: 'Dinner, taxi, groceries…',
              controller: description,
            ),
            SizedBox(height: AppSpacing.lg),
            _sheetLabel('Category'),
            _SelectField<String>(
              value: category,
              options: {for (final item in _crib.categories) item: item},
              dialogTitle: 'Category',
              onChanged: (value) => setSheetState(() => category = value),
            ),
            SizedBox(height: AppSpacing.lg),
            _sheetLabel('Split'),
            SplitShareEditor(
              members: _activeMembers,
              amountController: amount,
              currency: _crib.currency,
              initialShares: {},
              payerId: _meId,
              onChanged: (s, ok) {
                shares = s;
                splitComplete = ok;
              },
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: splitEqually ? 'Split bill' : 'Add expense',
        onPressed: () async {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          if (description.text.trim().isEmpty) {
            showAppToast(context, 'Add a short description');
            return;
          }
          if (!splitComplete || shares == null) {
            showAppToast(
              context,
              'The split has to add up to the whole amount',
            );
            return;
          }
          _addEntry(
            description: description.text.trim(),
            amount: minor,
            shares: shares ?? _equalShares(minor),
            category: category,
          ).then((added) {
            if (!added || !mounted) return;
            Navigator.of(context).pop();
            showQuirkyConfirm(
              context,
              splitEqually
                  ? 'Bill split — nice one!'
                  : 'Expense added — all set!',
            );
          });
        },
      ),
    );
  }

  void _showRecurringTransferSheet({RecurringPayment? existing}) {
    final editing = existing != null;
    final amount = TextEditingController(
      text: editing ? _plainAmount(existing.amountMinor) : '',
    );
    final description = TextEditingController(
      text: editing ? existing.description : '',
    );
    final recipients = _activeMembers
        .where((member) => member.id != _meId)
        .toList();
    if (recipients.isEmpty) {
      showAppToast(context, 'Add someone to the crib first');
      return;
    }
    var category = editing ? existing.category : _crib.categories.first;
    var frequency = editing ? existing.frequency : RecurringFrequency.monthly;
    var dueDate = editing ? existing.startDate : DateTime.now();
    var recipientId = editing && recipients.any((m) => m.id == existing.recipientId)
        ? existing.recipientId
        : recipients.first.id;

    _showFormDialog(
      title: editing ? 'Edit recurring transfer' : 'Set up recurring transfer',
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetLabel('Amount'),
            AmountField(
              currencySymbol: AppSettings.instance.currencySymbol,
              controller: amount,
              autofocus: false,
            ),
            SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'What is this for?',
              hint: 'Pocket money, repayment…',
              controller: description,
            ),
            SizedBox(height: AppSpacing.lg),
            _sheetLabel('Send to'),
            _SelectField<String>(
              value: recipientId,
              options: {for (final member in recipients) member.id: member.name},
              dialogTitle: 'Send to',
              onChanged: (value) => setSheetState(() => recipientId = value),
            ),
            SizedBox(height: AppSpacing.lg),
            _PickerTile(
              label: 'First payment date',
              value: '${dueDate.day}/${dueDate.month}/${dueDate.year}',
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(Duration(days: 1)),
                  initialDate: dueDate,
                  lastDate: DateTime.now().add(Duration(days: 3650)),
                );
                if (selected != null) setSheetState(() => dueDate = selected);
              },
            ),
            SizedBox(height: AppSpacing.md),
            _PickerTile(
              label: 'Repeats',
              value: frequency == RecurringFrequency.monthly
                  ? 'Every month'
                  : 'Every year',
              onTap: () => setSheetState(() {
                frequency = frequency == RecurringFrequency.monthly
                    ? RecurringFrequency.yearly
                    : RecurringFrequency.monthly;
              }),
            ),
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                'A paid activity will be posted to this group on each due date.',
                style: AppTypography.body.copyWith(
                  color: _DPalette.current.grey,
                ),
              ),
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: editing ? 'Save changes' : 'Save recurring transfer',
        onPressed: () async {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          if (description.text.trim().isEmpty) {
            showAppToast(context, 'Add a short description');
            return;
          }
          try {
            if (editing) {
              await PayCalRepositories.instance.recurring.update(
                existing.copyWith(
                  description: description.text.trim(),
                  amountMinor: minor,
                  category: category,
                  frequency: frequency,
                  recipientId: recipientId,
                  startDate: dueDate,
                ),
              );
            } else {
              await PayCalRepositories.instance.recurring.create(
                RecurringPayment(
                  id: 'r${DateTime.now().millisecondsSinceEpoch}',
                  cribId: _crib.id,
                  description: description.text.trim(),
                  amountMinor: minor,
                  currency: _crib.currency,
                  category: category,
                  frequency: frequency,
                  recipientId: recipientId,
                  createdById: _meId,
                  startDate: dueDate,
                  timeZone: RecurringScheduler.deviceTimeZone(),
                ),
              );
            }
          } on RepositoryException catch (error) {
            if (mounted) showAppToast(context, error.message);
            return;
          }
          if (!mounted) return;
          await _postDueRecurringPayments();
          if (!mounted) return;
          Navigator.of(context).pop();
          showAppToast(
            context,
            editing
                ? 'Recurring transfer updated'
                : 'Recurring transfer saved',
          );
        },
      ),
    );
  }

  /// Catches up recurring transfers that are due.
  ///
  /// Generation happens when a crib is opened. There is no background job, so
  /// nothing is generated while the app is closed.
  Future<void> _postDueRecurringPayments() async {
    try {
      await PayCalRepositories.instance.recurring.generateDue(
        cribId: _crib.id,
        now: DateTime.now(),
      );
    } on RepositoryException catch (_) {
      // A member who may not trigger a catch-up simply sees no new entries.
      return;
    }
    if (mounted) setState(() {});
  }

  Map<String, int> _equalShares(int amount) {
    return FinancialLedger.equalSplit(
      totalMinor: amount,
      participantIds: _activeMembers.map((member) => member.id),
      payerId: _meId,
    );
  }

  Widget _sheetLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.caption.copyWith(
        color: _DPalette.current.grey,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );

  /// Records a payment through the expense repository so every entry is
  /// validated, versioned and recorded in the activity feed.
  Future<bool> _addEntry({
    required String description,
    required int amount,
    required Map<String, int> shares,
    required String category,
  }) async {
    try {
      await PayCalRepositories.instance.expenses.create(
        Expense(
          id: 'e${DateTime.now().millisecondsSinceEpoch}',
          cribId: _crib.id,
          description: description,
          totalMinor: amount,
          currency: _crib.currency,
          payerId: _meId,
          shares: shares,
          date: DateTime.now(),
          category: category,
          createdById: _meId,
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) showAppToast(context, error.message);
      return false;
    }
    if (mounted) setState(() {});
    return true;
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x080A0A0A), Color(0x080A0A0A), Color(0x000A0A0A)],
        stops: [0, .58, 1],
      ).createShader(Rect.fromLTWH(0, 0, s.width, 180))
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (double y = 0; y < 180 && y < s.height; y += 6) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter o) => false;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: CircleBorder(),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppPalette.current.card,
        shape: BoxShape.circle,
        border: Border.all(color: _DPalette.current.ink, width: 1.5),
      ),
      child: Icon(icon, size: 20, color: _DPalette.current.ink),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.crib,
    required this.onBack,
    required this.onDetails,
    required this.onSettleUp,
  });
  final Crib crib;
  final VoidCallback onBack;
  final VoidCallback onDetails;
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(
      children: [
        _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                crib.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  color: _DPalette.current.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${crib.activeMembers.length} people',
                style: AppTypography.caption.copyWith(
                  color: _DPalette.current.grey,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_CribMenuAction>(
          offset: Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _DPalette.current.ink, width: 1.5),
          ),
          color: AppPalette.current.card,
          onSelected: (action) {
            if (action == _CribMenuAction.groupDetails) {
              onDetails();
            } else if (action == _CribMenuAction.settleUp) {
              onSettleUp();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _CribMenuAction.groupDetails,
              child: Text(
                'View group details',
                style: AppTypography.body.copyWith(
                  color: _DPalette.current.ink,
                ),
              ),
            ),
            PopupMenuItem(
              value: _CribMenuAction.settleUp,
              child: Text(
                'Settle up',
                style: AppTypography.body.copyWith(
                  color: _DPalette.current.ink,
                ),
              ),
            ),
          ],
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.current.card,
              shape: BoxShape.circle,
              border: Border.all(color: _DPalette.current.ink, width: 1.5),
            ),
            child: Icon(
              Icons.more_horiz,
              size: 20,
              color: _DPalette.current.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Signature geometric card: white top, lime bottom, purple + black wedge.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.crib, required this.net});
  final Crib crib;
  final int net;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, b) {
      final w = b.maxWidth;
      final h = (w * .50).clamp(165.0, 200.0);
      final caption = net > 0
          ? 'You are owed:'
          : (net < 0 ? 'You owe:' : 'All settled:');
      return SizedBox(
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _HeroPainter())),
            Positioned(
              left: 24,
              top: 20,
              right: w * .40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your balance in',
                    style: TextStyle(
                      color: _DPalette.current.grey,
                      fontSize: 13,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      crib.name,
                      style: AppTypography.title.copyWith(
                        color: _DPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: w * .30,
              bottom: 18,
              child: Row(
                children: [
                  _OverlapCircles(),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caption,
                          style: TextStyle(color: AppColors.ink, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MoneyText(
                            amount: net.abs(),
                            currency: crib.currency,
                            style: AppTypography.displayAmount.copyWith(
                              color: AppColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppPalette.current.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.groups_2_outlined,
                  color: _DPalette.current.ink,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HeroPainter extends CustomPainter {
  _HeroPainter();
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(28));
    c.save();
    c.clipRRect(rr);
    c.drawPaint(Paint()..color = _DPalette.current.card);
    final split = s.height * .45;
    c.drawRect(
      Rect.fromLTWH(0, split, s.width, s.height - split),
      Paint()..color = _DPalette.current.lime,
    );
    final topX = s.width * .66;
    final botX = s.width * .88;
    final splitX = topX + (botX - topX) * (split / s.height);
    c.drawPath(
      Path()
        ..moveTo(topX, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width, split)
        ..lineTo(splitX, split)
        ..close(),
      Paint()..color = _DPalette.current.purple,
    );
    c.drawPath(
      Path()
        ..moveTo(splitX, split)
        ..lineTo(s.width, split)
        ..lineTo(s.width, s.height)
        ..lineTo(botX, s.height)
        ..close(),
      Paint()..color = _DPalette.current.ink,
    );
    c.restore();
    c.drawRRect(
      rr.deflate(1),
      Paint()
        ..color = _DPalette.current.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(CustomPainter o) => true;
}

class _OverlapCircles extends StatelessWidget {
  const _OverlapCircles();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 38,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppPalette.current.card,
              shape: BoxShape.circle,
              border: Border.all(color: _DPalette.current.ink, width: 1.5),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 4,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _DPalette.current.pink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 36),
    decoration: BoxDecoration(
      color: _DPalette.current.chip,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, color: _DPalette.current.grey),
        SizedBox(height: 8),
        Text(
          'No payments in this crib yet.',
          style: AppTypography.caption.copyWith(color: _DPalette.current.grey),
        ),
      ],
    ),
  );
}

/// Themed tappable select field: opens a themed selection pop-up instead of
/// the native dropdown (which misbehaves inside dialogs).
class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.options,
    required this.dialogTitle,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> options;
  final String dialogTitle;
  final ValueChanged<T> onChanged;

  String get _label => options[value] ?? '';

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.current.card,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _DPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
                style: AppTypography.bodyLarge.copyWith(
                  color: _DPalette.current.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.expand_more_rounded,
              color: _DPalette.current.ink,
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );

  void _pick(BuildContext dialogContext) {
    showPopCard<T?>(
      context: dialogContext,
      title: dialogTitle,
      builder: (pickContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in options.entries)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: OptionTile(
                title: entry.value,
                selected: entry.key == value,
                onTap: () {
                  onChanged(entry.key);
                  Navigator.of(pickContext).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionOption extends StatelessWidget {
  const _ActionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.current.card,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _DPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 36,
              decoration: BoxDecoration(
                color: _DPalette.current.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: _DPalette.current.page, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: _DPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: _DPalette.current.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _DPalette.current.ink),
          ],
        ),
      ),
    ),
  );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.current.card,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _DPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: _DPalette.current.grey,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    value,
                    style: AppTypography.label.copyWith(
                      color: _DPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Tap to change',
              style: AppTypography.caption.copyWith(
                color: _DPalette.current.pink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _CribMenuAction { groupDetails, settleUp }

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final age = today.difference(day).inDays;
    final label = age == 0
        ? 'Today'
        : age == 1
        ? 'Yesterday'
        : '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _DPalette.current.ink,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentBubble extends StatelessWidget {
  const _PaymentBubble({
    required this.crib,
    required this.expense,
    this.onExpenseChanged,
  });

  final Crib crib;
  final Expense expense;
  final VoidCallback? onExpenseChanged;

  @override
  Widget build(BuildContext context) {
    final meId = PayCalRepositories.instance.currentUserId;
    final isMine = expense.payerId == meId;
    final payer = crib.memberById(expense.payerId);
    final myShare = expense.shares[meId] ?? 0;
    final foreground = isMine ? AppColors.ink : _DPalette.current.ink;

    final bubble = GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(
            expense: expense,
            onDone: () => onExpenseChanged?.call(),
          ),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? _DPalette.current.lime : _DPalette.current.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 22),
          ),
          border: Border.all(color: _DPalette.current.ink, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expense.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Money.format(expense.totalMinor, expense.currency),
                  style: AppTypography.label.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMine ? _DPalette.current.card : _DPalette.current.chip,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'My share ${Money.format(myShare, expense.currency)}',
                style: AppTypography.caption.copyWith(
                  color: isMine ? _DPalette.current.ink : foreground,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Avatar(initials: payer?.initials ?? '?', size: 30),
            SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
