import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';

/// Opens the themed "Create batch" pop-up. Returns true if a batch was
/// created so the caller can refresh its list.
Future<bool> showCreateBatch(BuildContext context) async {
  final created = await showPopCard<bool>(
    context: context,
    title: 'Create batch',
    builder: (dialogContext) => const _CreateBatchForm(),
  );
  return created ?? false;
}

class _CreateBatchForm extends StatefulWidget {
  const _CreateBatchForm();

  @override
  State<_CreateBatchForm> createState() => _CreateBatchFormState();
}

class _CreateBatchFormState extends State<_CreateBatchForm> {
  final name = TextEditingController();
  final member = TextEditingController();
  final members = <Member>[MockData.me];
  var currency = 'INR';
  static const _currencies = ['INR', 'USD', 'EUR'];

  void _addMember() {
    final text = member.text.trim();
    if (text.isEmpty) return;
    if (members.any((m) => m.name.toLowerCase() == text.toLowerCase())) {
      showAppToast(context, 'Already a member');
      return;
    }
    setState(() {
      members.add(
        Member(id: 'm${DateTime.now().millisecondsSinceEpoch}', name: text),
      );
      member.clear();
    });
  }

  void _create() {
    if (name.text.trim().isEmpty) {
      showAppToast(context, 'The batch needs a name first');
      return;
    }
    MockData.batches.add(
      Batch(
        id: 'b${DateTime.now().millisecondsSinceEpoch}',
        name: name.text.trim(),
        currency: currency,
        members: List.of(members),
        categories: ['food', 'transport', 'rent', 'groceries', 'other'],
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppTextField(
        label: 'Batch name',
        hint: 'Our flat, Goa trip…',
        controller: name,
      ),
      const SizedBox(height: AppSpacing.lg),
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
      const SizedBox(height: AppSpacing.lg),
      _miniLabel('Members'),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final m in members)
            _memberChip(m, removable: m.id != MockData.meId),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: 'Add a member',
        hint: "Friend's name…",
        controller: member,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _addMember(),
        suffix: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _addMember,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppPalette.current.lime,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              color: AppPalette.current.ink,
              size: 18,
            ),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(label: 'Create batch', onPressed: _create),
    ],
  );

  Widget _miniLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppPalette.current.ink : AppPalette.current.chip,
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

  Widget _memberChip(Member m, {required bool removable}) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md + 2,
      vertical: AppSpacing.sm + 2,
    ),
    decoration: BoxDecoration(
      color: m.id == MockData.meId ? AppPalette.current.lime : Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppPalette.current.ink, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.name,
          style: AppTypography.caption.copyWith(
            color: AppPalette.current.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (removable) ...[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => members.remove(m)),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppPalette.current.chip,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: AppPalette.current.ink,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
