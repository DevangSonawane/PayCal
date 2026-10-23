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
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/features/cribs/invite_link_sheet.dart';

/// Long-press editor for a crib: rename, currency, members, invite links,
/// and delete.
///
/// Metadata is saved as one update. Membership changes go through the crib
/// repository right away, so every add and removal is authorised, versioned
/// and recorded in the activity feed.
Future<void> showCribEdit(
  BuildContext context,
  Crib crib, {
  VoidCallback? onDone,
}) async {
  final name = TextEditingController(text: crib.name);
  var currency = crib.currency;
  var current = crib;
  var invitations = <Invitation>[];
  final repositories = PayCalRepositories.instance;
  final meId = repositories.currentUserId;
  // Only the Crib Owner may change anything here. The repositories enforce
  // that as well, so the checks below are for the interface, not the
  // security.
  final isOwner = crib.ownerId == meId;

  try {
    invitations = await repositories.invitations.list(cribId: crib.id);
  } on RepositoryException catch (_) {
    invitations = [];
  }
  if (!context.mounted) return;

  await showPopCard<void>(
    context: context,
    title: 'Edit crib',
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setPopState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOwner) AppTextField(label: 'Crib name', controller: name),
          if (isOwner) SizedBox(height: AppSpacing.md),
          if (!isOwner) ...[
            Text(
              crib.name,
              style: AppTypography.headline.copyWith(
                color: AppPalette.current.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '${crib.currency} · ${current.activeMembers.length} members',
              style: AppTypography.caption.copyWith(
                color: AppPalette.current.grey,
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],
          if (isOwner)
            Text(
            'CURRENCY',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          if (isOwner) SizedBox(height: AppSpacing.sm),
          if (isOwner)
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
          if (isOwner) SizedBox(height: AppSpacing.md),
          Text(
            'MEMBERS (${current.activeMembers.length})',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          for (final m in current.activeMembers)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Avatar(initials: m.initials, size: 32),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      // The owner is marked as such, and the signed-in member
                      // is marked as "You". A member is never labelled as the
                      // owner.
                      m.id == meId
                          ? (m.id == current.ownerId
                                ? 'You (owner)'
                                : 'You')
                          : (m.id == current.ownerId
                                ? '${m.name} (owner)'
                                : m.name),
                      style: AppTypography.label.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isOwner && m.id != current.ownerId)
                    GestureDetector(
                      onTap: () async {
                        try {
                          final updated = await repositories.cribs
                              .removeMember(
                                cribId: current.id,
                                memberId: m.id,
                              );
                          if (!context.mounted) return;
                          setPopState(() => current = updated);
                          onDone?.call();
                        } on RepositoryException catch (error) {
                          if (context.mounted) {
                            showAppToast(context, error.message);
                          }
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppPalette.current.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.current.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: AppPalette.current.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (isOwner) const SizedBox(height: AppSpacing.sm),
          if (isOwner)
            OptionTile(
            title: 'Invite someone',
            support: 'A private link that expires in 7 days',
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppPalette.current.lime,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.current.ink, width: 1.5),
              ),
              child: Icon(
                Icons.link_rounded,
                size: 18,
                color: AppPalette.current.ink,
              ),
            ),
            onTap: () async {
              // People join through a link, not through a name typed here:
              // only somebody with a real account can become a member.
              await showInviteLinkSheet(context, crib: current);
            },
          ),
          if (invitations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'INVITATIONS',
              style: AppTypography.caption.copyWith(
                color: AppPalette.current.grey,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final invitation in invitations)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _invitationLabel(invitation),
                        style: AppTypography.caption.copyWith(
                          color: AppPalette.current.grey,
                        ),
                      ),
                    ),
                    if (isOwner &&
                        !invitation.revoked &&
                        invitation.statusAt(DateTime.now()) ==
                            InvitationStatus.active)
                      GestureDetector(
                        onTap: () async {
                          try {
                            await repositories.invitations.revoke(
                              invitation.id,
                            );
                          } on RepositoryException catch (error) {
                            if (context.mounted) {
                              showAppToast(context, error.message);
                            }
                            return;
                          }
                          if (!context.mounted) return;
                          setPopState(() {
                            invitations = [
                              for (final item in invitations)
                                if (item.id == invitation.id)
                                  item.copyWith(revoked: true)
                                else
                                  item,
                            ];
                          });
                          if (context.mounted) {
                            showAppToast(context, 'Invitation revoked');
                          }
                        },
                        child: Text(
                          'Revoke',
                          style: AppTypography.caption.copyWith(
                            color: AppPalette.current.pink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (isOwner) const SizedBox(height: AppSpacing.md),
          if (isOwner)
            GestureDetector(
            onTap: () async {
              final ok = await showConfirmSheet(
                context: dialogContext,
                title: 'Delete "${crib.name}"?',
                body:
                    'Everyone loses access to the crib. Its expenses and '
                    'settlements stay in the ledger.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (ok == true && dialogContext.mounted) {
                try {
                  await PayCalRepositories.instance.cribs.delete(crib.id);
                } on RepositoryException catch (error) {
                  if (dialogContext.mounted) {
                    showAppToast(dialogContext, error.message);
                  }
                  return;
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                onDone?.call();
                showAppToast(dialogContext, 'Crib deleted');
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Delete crib',
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
      label: isOwner ? 'Save changes' : 'Close',
      onPressed: () async {
        if (!isOwner) {
          Navigator.of(context).pop();
          return;
        }
        final cleanName = name.text.trim();
        if (cleanName.isEmpty) {
          showAppToast(context, 'Cribs need a name');
          return;
        }
        try {
          await repositories.cribs.update(
            current.copyWith(name: cleanName, currency: currency),
          );
        } on RepositoryException catch (error) {
          if (context.mounted) showAppToast(context, error.message);
          return;
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
        onDone?.call();
        showAppToast(context, 'Crib updated');
      },
    ),
  );
}

String _invitationLabel(Invitation invitation) {
  switch (invitation.statusAt(DateTime.now())) {
    case InvitationStatus.revoked:
      return 'Revoked';
    case InvitationStatus.expired:
      return 'Expired';
    case InvitationStatus.accepted:
      return 'Joined';
    case InvitationStatus.active:
      final days = invitation.expiresAt.difference(DateTime.now()).inDays;
      return 'Expires in ${days < 0 ? 0 : days} days';
  }
}
