import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_spacing.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/avatar.dart';
import 'package:paycal/core/widgets/option_tile.dart';
import 'package:paycal/core/widgets/pop_card.dart';
import 'package:paycal/core/widgets/primary_button.dart';
import 'package:paycal/core/widgets/secondary_button.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/models.dart';
import 'package:paycal/data/pending_invitation.dart';
import 'package:paycal/data/repositories.dart';
import 'package:paycal/features/auth/create_account_screen.dart';
import 'package:paycal/features/auth/sign_in_screen.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/onboarding/onboarding_draft.dart';

/// Routes paycal:// links.
///
/// Only an opaque invitation token can change membership. A crib id in a URL
/// is never a credential: the `paycal://crib/...` and `paycal://batch/...`
/// links of earlier builds are rejected instead of joining a crib.
///
/// The links are handled wherever the member happens to be. An invitation
/// that is opened by somebody without an account is kept on the device and
/// accepted as soon as the member has an account, so the link never expires
/// in the gap between "I got the link" and "I made an account".
class DeepLinks {
  DeepLinks._();

  /// The navigator of the app.
  ///
  /// The links are not bound to one screen: a link can arrive while the
  /// member is signing in, in the middle of a crib or on the welcome screen.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final _links = AppLinks();
  static bool _listening = false;
  static Uri? _initialLink;

  /// Starts listening for links. Safe to call more than once.
  static void listen() {
    if (_listening) return;
    _listening = true;
    _links.uriLinkStream.listen(
      (uri) => unawaited(handle(uri)),
      onError: (Object _) {},
    );
  }

  /// Reads the link the app was started with.
  ///
  /// A link that opens the app from a cold start never reaches the stream,
  /// so it is picked up here and handled once the app is on screen.
  static Future<void> captureInitialLink() async {
    try {
      _initialLink = await _links.getInitialLink();
    } catch (_) {
      _initialLink = null;
    }
  }

  /// Handles the link the app was started with, if there was one.
  static Future<void> deliverInitialLink() async {
    final uri = _initialLink;
    _initialLink = null;
    if (uri != null) await handle(uri);
  }

  static Future<void> handle(Uri uri, [NavigatorState? navigator]) async {
    if (uri.scheme != 'paycal') return;
    final target = navigator ?? navigatorKey.currentState;
    if (target == null) return;
    switch (uri.host) {
      case 'user':
        _handleUser(uri.path.replaceAll('/', ''), target);
        return;
      case 'invite':
        await _handleInvitation(uri.path.replaceAll('/', ''), target);
        return;
      case 'crib':
      case 'batch':
        _handleLegacyCribLink(target);
        return;
      default:
        // Unknown link target: fill in when new host types exist.
        return;
    }
  }

  static Member? _findUser(String id) {
    for (final b in PayCalRepositories.instance.cribs.cachedCribs) {
      for (final m in b.members) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  static void _handleUser(String id, NavigatorState navigator) {
    final member = _findUser(id);
    if (member == null) return;
    final context = navigator.context;
    showPopCard<void>(
      context: context,
      title: 'Tabbb user',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(initials: member.initials, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppPalette.current.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ID $id',
                      style: AppTypography.caption.copyWith(
                        color: AppPalette.current.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final b in PayCalRepositories.instance.cribs.cachedCribs)
            if (b.members.any((m) => m.id == member.id) &&
                b.members.any(
                  (m) =>
                      m.id == PayCalRepositories.instance.auth.currentUser?.id,
                ))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OptionTile(
                  title: 'With ${b.name}',
                  support: 'A crib you both share',
                  onTap: () {
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (_) => CribDetailScreen(crib: b),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
      footer: PrimaryButton(label: 'Close', onPressed: () => navigator.pop()),
    );
  }

  /// Links of the shape `paycal://crib/<cribId>` (and the `paycal://batch/...`
  /// links of earlier builds) carried no secret. They must not add anybody to
  /// a crib.
  static void _handleLegacyCribLink(NavigatorState navigator) {
    final context = navigator.context;
    if (context.mounted) {
      showAppToast(
        context,
        'That invite link is out of date. Ask for a fresh one.',
      );
    }
  }

  /// Accepts an invitation.
  ///
  /// A member without an account cannot join yet: the server only lets a
  /// signed-in member into a crib. The token is kept on the device and
  /// accepted as soon as the member has an account, so the invitation does
  /// not get lost between the link and the sign-up.
  static Future<void> _handleInvitation(
    String token,
    NavigatorState navigator,
  ) async {
    final context = navigator.context;
    if (token.isEmpty) {
      if (context.mounted) {
        showAppToast(context, 'That invitation link is incomplete');
      }
      return;
    }
    final signedIn = PayCalRepositories.instance.auth.currentUser != null;
    if (!signedIn) {
      await PendingInvitation.store(token);
      if (!context.mounted) return;
      _askToSignIn(context, navigator);
      return;
    }
    await acceptInvitation(token, navigator);
  }

  /// Accepts a token for a signed-in member and opens the crib.
  static Future<void> acceptInvitation(
    String token,
    NavigatorState navigator,
  ) async {
    final context = navigator.context;
    try {
      final crib = await PayCalRepositories.instance.invitations.accept(token);
      if (!context.mounted) return;
      showAppToast(context, 'You joined ${crib.name}');
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => CribDetailScreen(crib: crib)),
      );
    } on RepositoryException catch (error) {
      if (context.mounted) showAppToast(context, error.message);
    } catch (_) {
      if (context.mounted) {
        showAppToast(
          context,
          'That invitation is invalid, expired, or unavailable',
        );
      }
    }
  }

  /// Offers the two ways into an account after an invitation was opened.
  static void _askToSignIn(BuildContext context, NavigatorState navigator) {
    showPopCard<void>(
      context: context,
      title: 'You are invited',
      builder: (_) => Text(
        'Someone invited you to a Tabbb crib. Create an account or sign in '
        'to join. Your invitation is saved on this device until then.',
        style: AppTypography.body.copyWith(color: AppPalette.current.grey),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Create an account',
            onPressed: () {
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CreateAccountScreen(draft: OnboardingDraft()),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'I already have an account',
            onPressed: () {
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
