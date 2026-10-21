import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';

/// Opens the themed "Create crib" pop-up. Returns the new crib so the caller
/// can hand out an invite link right away.
Future<Crib?> showCreateCrib(BuildContext context) async {
  final created = await showPopCard<Crib>(
    context: context,
    title: 'Create crib',
    builder: (dialogContext) => _CreateCribForm(),
  );
  return created;
}

class _CreateCribForm extends StatefulWidget {
  const _CreateCribForm();

  @override
  State<_CreateCribForm> createState() => _CreateCribFormState();
}

class _CreateCribFormState extends State<_CreateCribForm> {
  final name = TextEditingController();
  var currency = 'INR';
  static const _currencies = ['INR', 'USD', 'EUR'];

  Future<void> _create() async {
    if (name.text.trim().isEmpty) {
      showAppToast(context, 'The crib needs a name first');
      return;
    }
    Crib created;
    try {
      // People are not typed in here. They join through an invite link, so
      // the repository adds the creator as the owner and nobody else.
      created = await PayCalRepositories.instance.cribs.create(
        Crib(
          id: 'b${DateTime.now().millisecondsSinceEpoch}',
          name: name.text.trim(),
          currency: currency,
          members: const [],
          categories: ['food', 'transport', 'rent', 'groceries', 'other'],
        ),
      );
    } on RepositoryException catch (error) {
      if (mounted) showAppToast(context, error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppTextField(
        label: 'Crib name',
        hint: 'Our flat, Goa trip…',
        controller: name,
      ),
      SizedBox(height: AppSpacing.lg),
      _miniLabel('Currency'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final item in _currencies)
            _chip(
              item,
              selected: currency == item,
              onTap: () => setState(() => currency = item),
            ),
        ],
      ),
      SizedBox(height: AppSpacing.lg),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppPalette.current.lime,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              color: AppPalette.current.ink,
              size: 22,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Next you get a private invite link. Share it and everybody '
                'joins with their own account.',
                style: AppTypography.label.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.lg),
      PrimaryButton(label: 'Create crib', onPressed: _create),
    ],
  );

  Widget _miniLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppPalette.current.grey,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppPalette.current.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : AppPalette.current.ink,
        ),
      ),
    ),
  );
}
