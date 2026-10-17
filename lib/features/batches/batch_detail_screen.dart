import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/amount_field.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/expenses/expense_detail_screen.dart';

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
  Widget build(BuildContext context) {
    final expenses =
        MockData.expenses
            .where((expense) => expense.batchId == widget.batch.id)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.batch.name,
              style: AppTypography.title.copyWith(color: AppColors.textPrimary),
            ),
            Text(
              '${widget.batch.members.length} people',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_BatchMenuAction>(
            icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
            onSelected: (action) {
              if (action == _BatchMenuAction.groupDetails) {
                _showGroupDetails(context, widget.batch);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _BatchMenuAction.groupDetails,
                child: Text('View group details'),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: expenses.isEmpty
                ? Center(
                    child: Text(
                      'No payments in this batch yet.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      112,
                    ),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final previous = index == 0 ? null : expenses[index - 1];
                      final showDate =
                          previous == null ||
                          !_isSameDay(previous.date, expense.date);
                      return Column(
                        children: [
                          if (showDate) _DateLabel(date: expense.date),
                          _PaymentBubble(batch: widget.batch, expense: expense),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActions,
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  void _showGroupDetails(BuildContext context, Batch batch) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheetTop),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppRadii.chipPill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                batch.name,
                style: AppTypography.title.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${batch.members.length} members',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...batch.members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Avatar(initials: member.initials, size: 36),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        member.id == MockData.meId ? 'You' : member.name,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (member.isAdmin) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Admin',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheetTop),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionOption(
                icon: Icons.payments_outlined,
                title: 'Add money',
                subtitle: 'Record money paid to someone',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showAddMoneySheet();
                },
              ),
              _ActionOption(
                icon: Icons.receipt_long_outlined,
                title: 'Add expense',
                subtitle: 'Record something you paid for',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showExpenseSheet(splitEqually: false);
                },
              ),
              _ActionOption(
                icon: Icons.call_split_outlined,
                title: 'Split bill',
                subtitle: 'Divide a cost equally with the group',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showExpenseSheet(splitEqually: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMoneySheet() {
    final amount = TextEditingController();
    var recipientId = widget.batch.members
        .firstWhere((member) => member.id != MockData.meId)
        .id;
    showAppBottomSheet(
      context: context,
      title: 'Add money',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountField(currencySymbol: '₹', controller: amount),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: recipientId,
              decoration: _selectionDecoration('Paid to'),
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              dropdownColor: AppColors.surfaceRaised,
              menuMaxHeight: 240,
              items: widget.batch.members
                  .where((member) => member.id != MockData.meId)
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setSheetState(() => recipientId = value!),
            ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: 'Add money',
        onPressed: () {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Enter an amount first');
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
          showAppToast(context, 'Money added to ${recipient.name}');
        },
      ),
    );
  }

  void _showExpenseSheet({required bool splitEqually}) {
    final amount = TextEditingController();
    final description = TextEditingController();
    var category = widget.batch.categories.first;
    showAppBottomSheet(
      context: context,
      title: splitEqually ? 'Split bill' : 'Add expense',
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AmountField(currencySymbol: '₹', controller: amount),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'What was it for?',
              hint: 'Dinner, taxi, groceries…',
              controller: description,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: _selectionDecoration('Category'),
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              dropdownColor: AppColors.surfaceRaised,
              menuMaxHeight: 240,
              items: widget.batch.categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setSheetState(() => category = value!),
            ),
            if (splitEqually)
              Text(
                'Split equally between ${widget.batch.members.length} people',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      footer: PrimaryButton(
        label: splitEqually ? 'Split bill' : 'Add expense',
        onPressed: () {
          final minor = Money.tryParseToMinor(amount.text);
          if (minor == null || minor <= 0) {
            showAppToast(context, 'Enter an amount first');
            return;
          }
          if (description.text.trim().isEmpty) {
            showAppToast(context, 'Add a short description');
            return;
          }
          _addEntry(
            description: description.text.trim(),
            amount: minor,
            shares: splitEqually ? _equalShares(minor) : {MockData.meId: minor},
            category: category,
          );
          Navigator.of(context).pop();
          showAppToast(
            context,
            splitEqually ? 'Bill split with the group' : 'Expense added',
          );
        },
      ),
    );
  }

  Map<String, int> _equalShares(int amount) {
    final share = amount ~/ widget.batch.members.length;
    final remainder = amount % widget.batch.members.length;
    return {
      for (var index = 0; index < widget.batch.members.length; index++)
        widget.batch.members[index].id: share + (index < remainder ? 1 : 0),
    };
  }

  InputDecoration _selectionDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      borderSide: const BorderSide(color: AppColors.textPrimary),
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.textPrimary),
    title: Text(
      title,
      style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
    ),
    subtitle: Text(
      subtitle,
      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
    ),
    onTap: onTap,
  );
}

enum _BatchMenuAction { groupDetails }

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.chipPill),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentBubble extends StatelessWidget {
  const _PaymentBubble({required this.batch, required this.expense});

  final Batch batch;
  final Expense expense;

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
          builder: (_) => ExpenseDetailScreen(expense: expense),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.owedTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.tile),
          border: Border.all(
            color: isMine ? AppColors.owedTint : AppColors.border,
          ),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  Money.format(expense.totalMinor, expense.currency),
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'My share ${Money.format(myShare, expense.currency)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
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
            Avatar(initials: payer.initials, size: 28),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
