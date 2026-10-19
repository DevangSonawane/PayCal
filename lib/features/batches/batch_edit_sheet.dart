import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/data/mock_data.dart';
import 'package:paycal/data/models.dart';
import 'package:share_plus/share_plus.dart';

/// Long-press editor for a batch: rename, currency, members, invite link,
/// and delete. Mutations replace the batch in MockData in one save.
Future<void> showBatchEdit(
  BuildContext context,
  Batch batch, {
  VoidCallback? onDone,
}) async {
  final name = TextEditingController(text: batch.name);
  var currency = batch.currency;
  final members = [...batch.members];
  final wasNames = {for (final m in members) m.id: m.name};

  await showPopCard<void>(
    context: context,
    title: 'Edit batch',
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setPopState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(label: 'Batch name', controller: name),
          const SizedBox(height: AppSpacing.md),
          Text(
            'CURRENCY',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final code in ['INR', 'USD', 'EUR', 'GBP'])
                StickerPill(
                  label: code,
                  selected: currency == code,
                  showCheck: true,
                  onTap: () => setPopState(() => currency = code),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'MEMBERS (${members.length})',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Avatar(initials: m.initials, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      m.id == MockData.meId ? 'You (admin)' : m.name,
                      style: AppTypography.label.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (m.id != MockData.meId)
                    GestureDetector(
                      onTap: () => setPopState(() => members.remove(m)),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppPalette.current.ink, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: AppPalette.current.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          OptionTile(
            title: 'Add someone',
            support: 'They land in the batch when you save',
            onTap: () async {
              final nameCtrl = TextEditingController();
              final added = await showPopCard<String>(
                context: dialogContext,
                title: 'Add member',
                builder: (_) => AppTextField(
                  label: 'Name or nickname',
                  controller: nameCtrl,
                ),
                footer: PrimaryButton(
                  label: 'Add',
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      showAppToast(dialogContext, 'Give them a name');
                      return;
                    }
                    Navigator.of(dialogContext).pop(nameCtrl.text.trim());
                  },
                ),
              );
              if (added != null && added.isNotEmpty) {
                final id = 'u${DateTime.now().millisecondsSinceEpoch}';
                setPopState(() {
                  members.add(Member(id: id, name: added));
                  wasNames[id] = added;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OptionTile(
            title: 'Share invite link',
            support: 'paycal://batch/${batch.id}',
            onTap: () async {
              await SharePlus.instance.share(
                ShareParams(
                  text:
                      'Join my batch "${batch.name}" on PayCal: '
                      'paycal://batch/${batch.id}',
                  title: 'PayCal invite',
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () async {
              final ok = await showConfirmSheet(
                context: dialogContext,
                title: 'Delete "${batch.name}"?',
                body: 'Everyone loses access and its expenses go with it.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok == true && dialogContext.mounted) {
                MockData.batches.remove(batch);
                MockData.expenses.removeWhere((e) => e.batchId == batch.id);
                Navigator.of(dialogContext).pop();
                onDone?.call();
                showAppToast(context, 'Batch deleted');
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Delete batch',
                style: AppTypography.label.copyWith(
                  color: AppPalette.current.oweText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    footer: PrimaryButton(
      label: 'Save changes',
      onPressed: () {
        final cleanName = name.text.trim();
        if (cleanName.isEmpty) {
          showAppToast(context, 'Batches need a name');
          return;
        }
        final updated = Batch(
          id: batch.id,
          name: cleanName,
          currency: currency,
          members: members,
          categories: batch.categories,
        );
        final i = MockData.batches.indexOf(batch);
        if (i >= 0) {
          MockData.batches[i] = updated;
        }
        Navigator.of(context).pop();
        onDone?.call();
        showAppToast(context, 'Batch updated');
      },
    ),
  );
}
