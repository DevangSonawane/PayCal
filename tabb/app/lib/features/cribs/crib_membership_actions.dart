import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_bottom_sheet.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/repositories.dart';

/// The membership changes a member can make on a crib.
///
/// They live in one place because two screens offer them: the crib itself and
/// the account screen, where a member has to get out of every crib before the
/// account can go.
class CribMembershipActions {
  const CribMembershipActions._();

  /// Leaves the crib.
  ///
  /// The member keeps their history and their share of what was already
  /// spent, but is never charged again. Returns whether the member left.
  static Future<bool> leave(BuildContext context, Crib crib) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Leave ${crib.name}?',
      body: 'You stop taking part in ${crib.name}. What you already paid for '
          'and what you still owe stay in the history. The owner can invite '
          'you back later.',
      confirmLabel: 'Leave the crib',
      destructive: true,
    );
    if (confirmed != true) return false;
    try {
      await PayCalRepositories.instance.cribs.leave(crib.id);
    } on RepositoryException catch (error) {
      if (context.mounted) showAppToast(context, error.message);
      return false;
    }
    if (context.mounted) showAppToast(context, 'You left ${crib.name}');
    return true;
  }

  /// Hands the crib over to another member of the crib.
  ///
  /// Returns whether the crib changed hands.
  static Future<bool> transferOwnership(BuildContext context, Crib crib) async {
    final meId = PayCalRepositories.instance.auth.currentUser?.id;
    final candidates = crib.activeMembers
        .where((member) => member.id != meId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      showAppToast(context, 'Invite somebody first');
      return false;
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
              color: AppPalette.current.grey,
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
    if (newOwner == null || !context.mounted) return false;
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Hand over ${crib.name}?',
      body: '${newOwner.name} becomes the Crib Owner of ${crib.name}. '
          'You stay a member and keep your own history.',
      confirmLabel: 'Hand it over',
    );
    if (confirmed != true) return false;
    try {
      await PayCalRepositories.instance.cribs.transferOwnership(
        cribId: crib.id,
        newOwnerId: newOwner.id,
      );
    } on RepositoryException catch (error) {
      if (context.mounted) showAppToast(context, error.message);
      return false;
    }
    if (context.mounted) {
      showAppToast(context, '${newOwner.name} is the new Crib Owner');
    }
    return true;
  }

  /// Deletes the crib.
  ///
  /// The financial history of the crib is kept, so the expenses and the
  /// settlements of the other members stay reachable. Owner only. Returns
  /// whether the crib is gone.
  static Future<bool> deleteCrib(BuildContext context, Crib crib) async {
    final confirmed = await showConfirmSheet(
      context: context,
      title: 'Delete ${crib.name}?',
      body: 'The crib disappears for everybody. The expenses and the '
          'settlements stay in the history of the members that were in it.',
      confirmLabel: 'Delete the crib',
      destructive: true,
    );
    if (confirmed != true) return false;
    try {
      await PayCalRepositories.instance.cribs.delete(
        crib.id,
        expectedVersion: crib.version,
      );
    } on RepositoryException catch (error) {
      if (context.mounted) showAppToast(context, error.message);
      return false;
    }
    if (context.mounted) showAppToast(context, '${crib.name} is deleted');
    return true;
  }
}
