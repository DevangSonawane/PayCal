import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/settings/app_settings.dart';
import 'package:paycal/core/notifications/push_notification_service.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_text_field.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/confirm_sheet.dart';
import 'package:paycal/core/widgets/money_text.dart';
import 'package:paycal/core/widgets/party_tap.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/core/widgets/sticker_pill.dart';
import 'package:paycal/core/widgets/wedge_loader.dart';
import 'package:paycal/core/utils/party_mode.dart';
import 'package:paycal/core/utils/money.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/domain/financial_ledger.dart';
import 'package:paycal/features/cribs/crib_membership_actions.dart';
import 'package:paycal/features/cribs/invite_link_sheet.dart';
import 'package:paycal/features/onboarding/welcome_screen.dart';

const _currencies = ['INR', 'USD', 'EUR', 'GBP'];

class _Palette {
  static AppPalette get current => AppPalette.current;
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
    for (double y = 0; y < math.min(s.height, 180); y += 6) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter o) => true;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  int _netForCrib(Crib b) =>
      FinancialLedger.balances(
        crib: b,
        expenses: PayCalRepositories.instance.expenses.cachedExpenses.where(
          (expense) => expense.cribId == b.id,
        ),
        settlements: PayCalRepositories.instance.settlements.cachedSettlements
            .where((settlement) => settlement.cribId == b.id),
      )[PayCalRepositories.instance.currentUserId] ??
      0;

  Future<void> _editProfile(BuildContext context) async {
    final name = TextEditingController(text: AppSettings.instance.userName);
    final email = TextEditingController(text: AppSettings.instance.userEmail);
    await showPopCard<void>(
      context: context,
      title: 'Edit profile',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(label: 'Display name', controller: name),
          SizedBox(height: AppSpacing.md),
          AppTextField(label: 'Email', controller: email),
        ],
      ),
      footer: PrimaryButton(
        label: 'Save',
        onPressed: () async {
          final cleanName = name.text.trim();
          final cleanEmail = email.text.trim();
          if (cleanName.isEmpty || !cleanEmail.contains('@')) {
            showAppToast(context, 'A name and a valid email are needed');
            return;
          }
          try {
            await PayCalRepositories.instance.auth.updateProfile(
              name: cleanName,
              email: cleanEmail,
            );
          } on RepositoryException catch (error) {
            if (context.mounted) showAppToast(context, error.message);
            return;
          }
          AppSettings.instance.update(
            userName: cleanName,
            userEmail: cleanEmail,
          );
          if (!context.mounted) return;
          Navigator.of(context).pop();
          showAppToast(context, 'Profile updated');
        },
      ),
    );
  }

  /// Turns the server's refusal into something the member can act on.
  ///
  /// The account can only go when it is not in a crib any more. The server
  /// says so in backend wording; the member needs the next step.
  String _deleteAccountMessage(RepositoryException error) {
    if (error.message.toLowerCase().contains('crib')) {
      return 'You are still in a crib. Leave it, or hand over the ones you '
          'own, and then your account can go.';
    }
    return error.message;
  }

  /// The cribs that keep the account from being deleted.
  ///
  /// A crib the member has already left does not count, and a deleted crib
  /// does not either.
  Future<List<Crib>> _cribsBlockingDeletion() async {
    final meId = PayCalRepositories.instance.auth.currentUser?.id;
    final cribs = await PayCalRepositories.instance.cribs.list();
    return cribs
        .where(
          (crib) =>
              !crib.isDeleted &&
              crib.activeMembers.any((member) => member.id == meId),
        )
        .toList(growable: false);
  }

  /// Asks the member to get out of the cribs they are still in.
  ///
  /// A member that only takes part leaves the crib on their own. A member
  /// that owns a crib cannot leave it: the crib has to be handed over or
  /// deleted first, so a crib never ends up without an owner.
  ///
  /// Returns whether the member is out of every crib.
  Future<bool> _getOutOfTheCribs(BuildContext context) async {
    final meId = PayCalRepositories.instance.auth.currentUser?.id;
    var blockers = await _cribsBlockingDeletion();
    if (!context.mounted) return false;

    final ready = await showPopCard<bool>(
      context: context,
      title: 'Leave the cribs first',
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An account can only go when it is not in a crib any more. Leave '
              'the cribs below, or hand over the ones you own, and your '
              'account can be deleted.',
              style: AppTypography.body.copyWith(
                color: AppPalette.current.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final crib in blockers) ...[
              _cribBlocker(context, crib, meId, () async {
                blockers = await _cribsBlockingDeletion();
                setState(() {});
              }),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (blockers.isEmpty) ...[
              PrimaryButton(
                label: 'Delete my account',
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ],
        ),
      ),
    );
    return ready == true;
  }

  /// One crib that keeps the account from being deleted, with the ways out.
  Widget _cribBlocker(
    BuildContext context,
    Crib crib,
    String? meId,
    Future<void> Function() onChanged,
  ) {
    final owns = crib.isOwnedBy(meId ?? '');
    final others = crib.activeMembers
        .where((member) => member.id != meId)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppPalette.current.card,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            crib.name,
            style: AppTypography.titleSmall.copyWith(
              color: AppPalette.current.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            owns ? 'You are the Crib Owner' : 'You are a member',
            style: AppTypography.caption.copyWith(color: AppPalette.current.grey),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (owns) ...[
            SecondaryButton(
              label: others.isEmpty
                  ? 'Invite / Hand Over'
                  : 'Hand Over',
              onPressed: () async {
                if (others.isEmpty) {
                  await showInviteLinkSheet(context, crib: crib);
                  return;
                }
                final handed = await CribMembershipActions.transferOwnership(
                  context,
                  crib,
                );
                if (handed) await onChanged();
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            SecondaryButton(
              label: 'Delete this crib',
              onPressed: () async {
                final deleted = await CribMembershipActions.deleteCrib(
                  context,
                  crib,
                );
                if (deleted) await onChanged();
              },
            ),
          ] else
            SecondaryButton(
              label: 'Leave this crib',
              onPressed: () async {
                final left = await CribMembershipActions.leave(context, crib);
                if (left) await onChanged();
              },
            ),
        ],
      ),
    );
  }

  /// Deletes the account.
  ///
  /// A member that is still in a crib is asked to get out of it first: the
  /// account is only deleted once no crib keeps it.
  Future<void> _deleteAccount(BuildContext context) async {
    List<Crib> blockers;
    try {
      blockers = await _cribsBlockingDeletion();
    } on RepositoryException catch (error) {
      if (context.mounted) showAppToast(context, error.message);
      return;
    }
    if (!context.mounted) return;
    if (blockers.isNotEmpty) {
      final ready = await _getOutOfTheCribs(context);
      if (!ready || !context.mounted) return;
    }
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete account?',
      body: 'This anonymises your profile. Outstanding balances stay visible '
          'to others.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await PayCalRepositories.instance.auth.deleteAccount();
      await AppSettings.instance.clearIdentity();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (r) => false,
      );
    } on RepositoryException catch (error) {
      if (context.mounted) {
        showAppToast(context, _deleteAccountMessage(error));
      }
    } catch (_) {
      if (context.mounted) {
        showAppToast(context, 'Unable to delete the account.');
      }
    }
  }

  Future<void> _accountDetails(BuildContext context) async {
    await showPopCard<void>(
      context: context,
      title: 'Account details',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSettings.instance.userEmail.contains('@')
              ? Text(
                  "${AppSettings.instance.userName} · ${AppSettings.instance.userEmail}",
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.ink,
                  ),
                )
              : Text(
                  'Signed in as ${AppSettings.instance.userName}.',
                  style: AppTypography.body.copyWith(
                    color: AppPalette.current.ink,
                  ),
                ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'CURRENCY',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final code in _currencies)
                StickerPill(
                  label: '${AppSettings.symbolForCode(code)} $code',
                  selected: AppSettings.instance.currencyCode == code,
                  showCheck: true,
                  onTap: () => AppSettings.instance.update(currencyCode: code),
                ),
            ],
          ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Looks good',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _notifications(BuildContext context) {
    return showPopCard<void>(
      context: context,
      title: 'Notifications',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            label: 'Tabbb updates',
            support: 'Know the second someone settles up',
            value: AppSettings.instance.notificationsOn,
            onChanged: (v) =>
                unawaited(PushNotificationService.instance.setEnabled(v)),
          ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Done',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _privacy(BuildContext context) {
    return showPopCard<void>(
      context: context,
      title: 'Privacy',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            label: 'Hide amounts by default',
            support: 'Balances blur on the home screen',
            value: AppSettings.instance.amountHidden,
            onChanged: (v) => AppSettings.instance.update(amountHidden: v),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Never sell your data. Your spends stay between the people in the crib.',
            style: AppTypography.caption.copyWith(
              color: AppPalette.current.grey,
            ),
          ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Got it',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _help(BuildContext context) => _staticPop(context, 'Help', [
    'Scan a friend\u2019s QR code to pay them or split a bill.',
    'Flip your balance card to show your code.',
    'Settle up from a crib menu to see the fewest transfers.',
  ]);

  Future<void> _terms(BuildContext context) =>
      _staticPop(context, 'Terms and Privacy', [
        'Tabbb is a demo app; all data lives on your device.',
        'Deleting a crib removes shared pending expenses for everyone.',
        'Flagged expenses keep the paper trail, so nobody gaslights you.',
      ]);

  Future<void> _balanceBreakdown(BuildContext context) async {
    final rows = [
      for (final b in PayCalRepositories.instance.cribs.cachedCribs)
        (b, _netForCrib(b)),
    ];
    final currency = AppSettings.instance.currencyCode;
    await showPopCard<void>(
      context: context,
      title: 'Your balance',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (b, net) in rows)
            Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: net == 0
                    ? AppPalette.current.lime
                    : AppPalette.current.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.current.ink, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      b.name,
                      style: AppTypography.label.copyWith(
                        color: net == 0
                            ? AppColors.ink
                            : AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (net == 0)
                    Text(
                      'Square',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    MoneyText(
                      amount: net.abs(),
                      currency: currency,
                      style: AppTypography.titleSmall.copyWith(
                        color: net == 0
                            ? AppColors.ink
                            : AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      direction: net > 0
                          ? MoneyDirection.owed
                          : MoneyDirection.owe,
                    ),
                ],
              ),
            ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _staticPop(
    BuildContext context,
    String title,
    List<String> points,
  ) {
    return showPopCard<void>(
      context: context,
      title: title,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in points)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WedgeBullet(color: AppPalette.current.pink, size: 9),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      p,
                      style: AppTypography.body.copyWith(
                        color: AppPalette.current.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      footer: PrimaryButton(
        label: 'Close',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (parts.isEmpty) return 'YO';
    final first = parts.first[0];
    final second = parts.length > 1
        ? parts.last[0]
        : (parts.first.length > 1 ? parts.first[1] : '');
    return '$first$second'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initialsOf(AppSettings.instance.userName);
    return Scaffold(
      backgroundColor: _Palette.current.page,
      body: CustomPaint(
        painter: _StripePainter(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            40,
            AppSpacing.xxl,
            MediaQuery.of(context).padding.bottom + 100,
          ),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              AppSettings.instance,
              PartyMode.instance,
            ]),
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _Palette.current.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.face_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Profile',
                        style: AppTypography.title.copyWith(
                          color: _Palette.current.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Spacer(),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(0xFFF0477F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xxl),
                PartyTap(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: PartyMode.instance.identityCard,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        Avatar(initials: initials, size: 56),
                        SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      AppSettings.instance.userName,
                                      style: AppTypography.titleSmall
                                          .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (PartyMode.instance.isOn) ...[
                                    SizedBox(width: AppSpacing.sm),
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: AppPalette.current.lime,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                AppSettings.instance.userEmail,
                                style: AppTypography.body.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              // The edit control sits *inside* the party tap so
                              // that its own gesture wins the arena: a nested
                              // detector deeper in the tree takes the tap, the
                              // outer party detector never sees it.
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _editProfile(context),
                                child: Container(
                                  margin: EdgeInsets.only(top: AppSpacing.sm),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.current.lime,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 13,
                                        color: AppColors.ink,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tap to edit profile',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                GestureDetector(
                  onTap: () => _balanceBreakdown(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.current.lime,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.ink,
                          size: 22,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Balance across cribs',
                            style: AppTypography.label.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.ink),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xxl),
                _group(context, 'Account', [
                  ('Account details', () => _accountDetails(context)),
                  ('Notifications', () => _notifications(context)),
                  ('Privacy', () => _privacy(context)),
                ]),
                _group(context, 'Support', [
                  ('Help', () => _help(context)),
                  ('Terms and Privacy', () => _terms(context)),
                ]),
                GestureDetector(
                  onTap: () => _deleteAccount(context),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'Delete account',
                      style: AppTypography.label.copyWith(
                        color: AppPalette.current.oweText,
                      ),
                    ),
                  ),
                ),
                Divider(color: AppPalette.current.border),
                GestureDetector(
                  onTap: () async {
                    final ok = await showConfirmSheet(
                      context: context,
                      title: 'Log out?',
                      body: 'You can sign back in anytime.',
                      confirmLabel: 'Log out',
                    );
                    if (ok == true && context.mounted) {
                      await PayCalRepositories.instance.auth.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const WelcomeScreen(),
                        ),
                        (r) => false,
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_outlined,
                          color: AppPalette.current.text,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Log out',
                          style: AppTypography.label.copyWith(
                            color: AppPalette.current.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    List<(String, VoidCallback)> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            WedgeBullet(color: AppPalette.current.pink, size: 11),
            SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: Color(0xFFF0477F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        ...rows.map((row) {
          final (label, action) = row;
          return GestureDetector(
            onTap: action,
            child: Container(
              margin: EdgeInsets.only(top: AppSpacing.sm),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppPalette.current.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.current.ink, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppPalette.current.text,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppPalette.current.textTertiary,
                  ),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _ToggleRow extends StatefulWidget {
  const _ToggleRow({
    required this.label,
    required this.support,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String support;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_ToggleRow> createState() => _ToggleRowState();
}

class _ToggleRowState extends State<_ToggleRow> {
  late bool value = widget.value;

  @override
  void didUpdateWidget(covariant _ToggleRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppPalette.current.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppPalette.current.ink, width: 1.5),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: AppTypography.label.copyWith(
                  color: AppPalette.current.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                widget.support,
                style: AppTypography.caption.copyWith(
                  color: AppPalette.current.grey,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() => value = !value);
            widget.onChanged(value);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value ? AppPalette.current.lime : AppPalette.current.chip,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppPalette.current.ink, width: 1.5),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppPalette.current.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
