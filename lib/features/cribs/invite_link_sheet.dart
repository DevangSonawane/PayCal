import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/config/app_config.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';
import 'package:share_plus/share_plus.dart';

/// Creates a private invitation for [crib] and shows its shareable link.
///
/// People join through a link, not through a name typed into a form: the link
/// carries an opaque token and the server only ever stores its hash, so a
/// crib id can never be used to walk into a crib. The token stays valid for
/// [AppConfig.invitationLifetime] and the owner can revoke it from the crib
/// editor.
///
/// Only the Crib Owner may invite. Everybody else sees the link as an
/// owner-only action, so the repository refusal never surprises anybody.
Future<void> showInviteLinkSheet(
  BuildContext context, {
  required Crib crib,
}) async {
  final repositories = PayCalRepositories.instance;
  final meId = repositories.currentUserId;
  if (meId.isEmpty) {
    showAppToast(context, 'Sign in to invite people');
    return;
  }

  final Invitation invitation;
  try {
    invitation = await repositories.invitations.create(
      cribId: crib.id,
      createdById: meId,
      expiresAt: DateTime.now().add(AppConfig.invitationLifetime),
    );
  } on RepositoryException catch (error) {
    if (context.mounted) showAppToast(context, error.message);
    return;
  }
  if (!context.mounted) return;

  final link = AppConfig.invitationLink(invitation.token);
  await showAppBottomSheet<void>(
    context: context,
    title: 'Invite to ${crib.name}',
    builder: (_) => _InviteLinkBody(link: link, cribName: crib.name),
    footer: PrimaryButton(
      label: 'Share invite link',
      onPressed: () async {
        await _copy(context, link);
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: 'Join "${crib.name}" on PayCal: $link',
              subject: 'PayCal invite',
            ),
          );
        } catch (_) {
          if (context.mounted) {
            showAppToast(
              context,
              'Invite link copied — paste it anywhere',
            );
          }
        }
      },
    ),
  );
}

Future<void> _copy(BuildContext context, String link) async {
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) showAppToast(context, 'Invite link copied');
}

class _InviteLinkBody extends StatelessWidget {
  const _InviteLinkBody({required this.link, required this.cribName});

  final String link;
  final String cribName;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
                'Share this private link. Whoever opens it joins '
                '"$cribName" with their own account.',
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
      Text(
        'INVITE LINK',
        style: AppTypography.caption.copyWith(
          color: AppPalette.current.grey,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      SizedBox(height: AppSpacing.sm),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppPalette.current.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.current.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link,
                style: AppTypography.body.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _copy(context, link),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppPalette.current.ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppPalette.current.lime,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.md),
      Text(
        'The link expires in ${AppConfig.invitationLifetime.inDays} days and '
        'can be revoked from the crib editor.',
        style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
      ),
    ],
  );
}
