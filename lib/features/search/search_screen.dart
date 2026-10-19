import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/features/batches/batch_detail_screen.dart';
import 'package:paycal/features/expenses/expense_detail_screen.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';

/// Full-page search across batches, expenses and people.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  String _text = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String? value) =>
      value != null && value.toLowerCase().contains(_text.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final batches = _text.isEmpty
        ? <Batch>[]
        : MockData.batches.where((b) => _matches(b.name)).toList();
    final expenses = _text.isEmpty
        ? <Expense>[]
        : MockData.expenses
              .where(
                (e) =>
                    _matches(e.description) ||
                    _matches(e.category) ||
                    _matches(MockData.memberName(e.payerId)),
              )
              .toList();
    final people = <Member>[];
    if (_text.isNotEmpty) {
      final seen = <String>{};
      for (final b in MockData.batches) {
        for (final m in b.members) {
          if (m.id == MockData.meId ||
              seen.contains(m.id) ||
              !_matches(m.name)) {
            continue;
          }
          seen.add(m.id);
          people.add(m);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppPalette.current.page,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.current.ink, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        size: 26,
                        color: AppPalette.current.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Search',
                      style: AppTypography.title.copyWith(
                        color: AppPalette.current.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: AppTextField(
                label: 'Batches, expenses, people',
                hint: 'Try "groceries" or "Asha"',
                controller: _query,
                onChanged: (v) => setState(() => _text = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  MediaQuery.of(context).padding.bottom + 100,
                ),
                children: [
                  if (_text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: Text(
                        'Start typing — results show up here.',
                        style: AppTypography.body.copyWith(
                          color: AppPalette.current.grey,
                        ),
                      ),
                    ),
                  if (_text.isNotEmpty &&
                      batches.isEmpty &&
                      expenses.isEmpty &&
                      people.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: Text(
                        'Nothing matches "$_text".',
                        style: AppTypography.body.copyWith(
                          color: AppPalette.current.grey,
                        ),
                      ),
                    ),
                  if (batches.isNotEmpty) ...[
                    _section('Batches'),
                    for (final b in batches)
                      _tile(
                        icon: Icons.groups_rounded,
                        title: b.name,
                        subtitle: '${b.members.length} members · ${b.currency}',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BatchDetailScreen(batch: b),
                            ),
                          );
                        },
                      ),
                  ],
                  if (expenses.isNotEmpty) ...[
                    _section('Expenses'),
                    for (final e in expenses)
                      _tile(
                        icon: Icons.receipt_long_rounded,
                        title: e.description,
                        subtitle:
                            '${MockData.memberName(e.payerId)} · ${e.category}',
                        trailing: MoneyText(
                          amount: e.totalMinor,
                          currency: e.currency,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppPalette.current.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ExpenseDetailScreen(expense: e),
                            ),
                          );
                        },
                      ),
                  ],
                  if (people.isNotEmpty) ...[
                    _section('People'),
                    for (final m in people)
                      _tile(
                        leading: Avatar(initials: m.initials, size: 36),
                        title: m.name,
                        subtitle: 'Send them money',
                        onTap: () {
                          Navigator.of(context).pop();
                          showQuickAdd(context, payeeId: m.id);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        color: AppPalette.current.pink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _tile({
    IconData? icon,
    Widget? leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppPalette.current.ink, width: 1.5),
          ),
          child: Row(
            children: [
              if (leading != null)
                leading
              else if (icon != null)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppPalette.current.lime,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppPalette.current.ink, width: 1.5),
                  ),
                  child: Icon(icon, size: 19, color: AppPalette.current.ink),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppPalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing,
              ],
              const Icon(Icons.chevron_right, size: 20, color: AppPalette.current.grey),
            ],
          ),
        ),
      ),
    ),
  );
}
