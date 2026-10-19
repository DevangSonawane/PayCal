import 'package:flutter/material.dart';
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
import 'package:paycal/core/widgets/quirky_confirm.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/domain/balance_engine.dart';
import 'package:paycal/features/expenses/expense_detail_screen.dart';
import 'package:paycal/features/expenses/split_share_editor.dart';
import 'package:paycal/features/settlements/settle_up_sheet.dart';

class _DPalette {
  static AppPalette get current => AppPalette.current;
}

/// A batch reads as a shared payment conversation: payments from the current
/// user are on the right and payments from everyone else are on the left.
class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({super.key, required this.batch});

  final Batch batch;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    _postDueRecurringPayments();
  }

  int _net(List<Expense> expenses) =>
      BalanceEngine.nets(
        expenses
            .map(
              (e) => ExpenseInput(
                totalMinor: e.totalMinor,
                payerId: e.payerId,
                shares: e.shares,
              ),
            )
            .toList(),
        widget.batch.members.map((m) => m.id).toList(),
      )[MockData.meId] ??
      0;

  @override
  Widget build(BuildContext context) {
    final expenses =
        MockData.expenses
            .where((expense) => expense.batchId == widget.batch.id)
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
                  batch: widget.batch,
                  onBack: () => Navigator.of(context).maybePop(),
                  onDetails: () => _showGroupDetails(context, widget.batch),
                  onSettleUp: () => showSettleUp(
                    context,
                    widget.batch,
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
                      _HeroCard(batch: widget.batch, net: net),
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
                            batch: widget.batch,
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

  void _showGroupDetails(BuildContext context, Batch batch) {
    final recurring = MockData.recurringPayments
        .where((r) => r.batchId == batch.id)
        .toList()
        .reversed
        .toList();
    showAppBottomSheet<void>(
      context: context,
      title: batch.name,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${batch.members.length} members',
            style: AppTypography.body.copyWith(color: _DPalette.current.grey),
          ),
          SizedBox(height: AppSpacing.lg),
          ...batch.members.map(
            (member) => Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Avatar(initials: member.initials, size: 38),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      member.id == MockData.meId ? 'You' : member.name,
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
                        'Admin',
                        style: AppTypography.caption.copyWith(
                          color: _DPalette.current.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
                              '${r.description} → ${MockData.memberName(r.recipientId)}',
                              style: AppTypography.label.copyWith(
                                color: _DPalette.current.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${Money.format(r.amountMinor, r.currency)} · every ${r.frequency == RecurringFrequency.monthly ? 'month' : 'year'} · next ${r.nextDueAt.day}/${r.nextDueAt.month}',
                              style: AppTypography.caption.copyWith(
                                color: _DPalette.current.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => MockData.recurringPayments.remove(r));
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

  void _showAddActions() {
    _showFormDialog(
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
          SizedBox(height: AppSpacing.md),
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
    var recipientId = widget.batch.members
        .firstWhere((member) => member.id != MockData.meId)
        .id;
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
              options: {
                for (final member in widget.batch.members)
                  if (member.id != MockData.meId) member.id: member.name,
              },
              dialogTitle: 'Paid to',
              onChanged: (value) => setSheetState(() => recipientId = value),
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: 'Add money',
        onPressed: () {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          final recipient = widget.batch.members.firstWhere(
            (member) => member.id == recipientId,
          );
          _addEntry(
            description: 'Money to ${recipient.name}',
            amount: minor,
            shares: {MockData.meId: minor},
            category: 'other',
          );
          Navigator.of(context).pop();
          showQuirkyConfirm(context, 'All set — money added!');
        },
      ),
    );
  }

  void _showExpenseSheet({required bool splitEqually}) {
    final amount = TextEditingController();
    final description = TextEditingController();
    var category = widget.batch.categories.first;
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
              options: {for (final item in widget.batch.categories) item: item},
              dialogTitle: 'Category',
              onChanged: (value) => setSheetState(() => category = value),
            ),
            SizedBox(height: AppSpacing.lg),
            _sheetLabel('Split'),
            SplitShareEditor(
              members: widget.batch.members,
              amountController: amount,
              currency: widget.batch.currency,
              initialShares: {},
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
        onPressed: () {
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
          );
          Navigator.of(context).pop();
          showQuirkyConfirm(
            context,
            splitEqually
                ? 'Bill split — nice one!'
                : 'Expense added — all set!',
          );
        },
      ),
    );
  }

  void _showRecurringTransferSheet() {
    final amount = TextEditingController();
    final description = TextEditingController();
    var category = widget.batch.categories.first;
    var frequency = RecurringFrequency.monthly;
    var dueDate = DateTime.now();
    var recipientId = widget.batch.members
        .firstWhere((member) => member.id != MockData.meId)
        .id;

    _showFormDialog(
      title: 'Set up recurring transfer',
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
              options: {
                for (final member in widget.batch.members)
                  if (member.id != MockData.meId) member.id: member.name,
              },
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
        label: 'Save recurring transfer',
        onPressed: () {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Pop in an amount first');
            return;
          }
          if (description.text.trim().isEmpty) {
            showAppToast(context, 'Add a short description');
            return;
          }
          MockData.recurringPayments.add(
            RecurringPayment(
              id: 'r${MockData.recurringPayments.length + 1}',
              batchId: widget.batch.id,
              description: description.text.trim(),
              amountMinor: minor,
              currency: widget.batch.currency,
              category: category,
              frequency: frequency,
              nextDueAt: dueDate,
              recipientId: recipientId,
            ),
          );
          setState(_postDueRecurringPayments);
          Navigator.of(context).pop();
          showAppToast(context, 'Recurring transfer saved');
        },
      ),
    );
  }

  void _postDueRecurringPayments() {
    final now = DateTime.now();
    for (final payment in MockData.recurringPayments.where(
      (item) => item.batchId == widget.batch.id,
    )) {
      while (!payment.nextDueAt.isAfter(now)) {
        MockData.expenses.add(
          Expense(
            id: 'rec-${payment.id}-${payment.nextDueAt.millisecondsSinceEpoch}',
            batchId: payment.batchId,
            description:
                '${payment.description} to ${MockData.memberName(payment.recipientId)}',
            totalMinor: payment.amountMinor,
            currency: payment.currency,
            payerId: MockData.meId,
            shares: {MockData.meId: payment.amountMinor},
            date: payment.nextDueAt,
            category: payment.category,
          ),
        );
        payment.nextDueAt = _nextOccurrence(
          payment.nextDueAt,
          payment.frequency,
        );
      }
    }
  }

  DateTime _nextOccurrence(DateTime date, RecurringFrequency frequency) =>
      frequency == RecurringFrequency.monthly
      ? DateTime(date.year, date.month + 1, date.day)
      : DateTime(date.year + 1, date.month, date.day);

  Map<String, int> _equalShares(int amount) {
    final share = amount ~/ widget.batch.members.length;
    final remainder = amount % widget.batch.members.length;
    return {
      for (var index = 0; index < widget.batch.members.length; index++)
        widget.batch.members[index].id: share + (index < remainder ? 1 : 0),
    };
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

  void _addEntry({
    required String description,
    required int amount,
    required Map<String, int> shares,
    required String category,
  }) {
    setState(() {
      MockData.expenses.add(
        Expense(
          id: 'e${MockData.expenses.length + 1}',
          batchId: widget.batch.id,
          description: description,
          totalMinor: amount,
          currency: widget.batch.currency,
          payerId: MockData.meId,
          shares: shares,
          date: DateTime.now(),
          category: category,
        ),
      );
    });
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
    required this.batch,
    required this.onBack,
    required this.onDetails,
    required this.onSettleUp,
  });
  final Batch batch;
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
                batch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  color: _DPalette.current.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${batch.members.length} people',
                style: AppTypography.caption.copyWith(
                  color: _DPalette.current.grey,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<_BatchMenuAction>(
          offset: Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _DPalette.current.ink, width: 1.5),
          ),
          color: Colors.white,
          onSelected: (action) {
            if (action == _BatchMenuAction.groupDetails) {
              onDetails();
            } else if (action == _BatchMenuAction.settleUp) {
              onSettleUp();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _BatchMenuAction.groupDetails,
              child: Text('View group details'),
            ),
            PopupMenuItem(
              value: _BatchMenuAction.settleUp,
              child: Text('Settle up'),
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
  const _HeroCard({required this.batch, required this.net});
  final Batch batch;
  final int net;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, b) {
      final w = b.maxWidth;
      final h = (w * .50).clamp(165.0, 200.0);
      final direction = net > 0
          ? MoneyDirection.owed
          : (net < 0 ? MoneyDirection.owe : null);
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
                      batch.name,
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
                          style: TextStyle(
                            color: _DPalette.current.ink,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MoneyText(
                            amount: net.abs(),
                            currency: batch.currency,
                            style: AppTypography.displayAmount.copyWith(
                              color: _DPalette.current.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                            direction: direction,
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
    c.drawPaint(Paint()..color = Colors.white);
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
  bool shouldRepaint(CustomPainter o) => false;
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
          'No payments in this batch yet.',
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
              child: Icon(icon, color: Colors.white, size: 20),
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

enum _BatchMenuAction { groupDetails, settleUp }

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
    required this.batch,
    required this.expense,
    this.onExpenseChanged,
  });

  final Batch batch;
  final Expense expense;
  final VoidCallback? onExpenseChanged;

  @override
  Widget build(BuildContext context) {
    final isMine = expense.payerId == MockData.meId;
    final payer = batch.members.firstWhere(
      (member) => member.id == expense.payerId,
    );
    final myShare = expense.shares[MockData.meId] ?? 0;

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
          color: isMine ? _DPalette.current.lime : Colors.white,
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
                      color: _DPalette.current.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Money.format(expense.totalMinor, expense.currency),
                  style: AppTypography.label.copyWith(
                    color: _DPalette.current.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMine ? Colors.white : _DPalette.current.chip,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'My share ${Money.format(myShare, expense.currency)}',
                style: AppTypography.caption.copyWith(
                  color: _DPalette.current.ink,
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
            Avatar(initials: payer.initials, size: 30),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
