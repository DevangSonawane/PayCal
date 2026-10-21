import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/widgets/app_toast.dart';
import 'package:paycal/core/widgets/solid_bottom_nav.dart';
import 'package:paycal/data/in_memory_repositories.dart';
import 'package:paycal/data/pending_invitation.dart';
import 'package:paycal/features/activity/activity_screen.dart';
import 'package:paycal/features/cribs/crib_detail_screen.dart';
import 'package:paycal/features/cribs/cribs_screen.dart';
import 'package:paycal/features/home/home_screen.dart';
import 'package:paycal/features/profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // An invitation that was opened before the member had an account is
    // accepted now: the shell is where every sign-in ends up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinPendingCrib());
  }

  /// Accepts an invitation the member opened while they were signed out.
  Future<void> _joinPendingCrib() async {
    final token = await PendingInvitation.read();
    if (token == null) return;
    try {
      final crib = await PayCalRepositories.instance.invitations.accept(token);
      await PendingInvitation.clear();
      if (!mounted) return;
      showAppToast(context, 'You joined ${crib.name}');
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CribDetailScreen(crib: crib)),
      );
    } catch (_) {
      // The invitation is gone, expired or was already used. It is dropped
      // so it does not come back on every launch.
      await PendingInvitation.clear();
      if (!mounted) return;
      showAppToast(
        context,
        'That invitation is invalid, expired, or unavailable',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.current.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  onDestinationSelected: (i) => setState(() => _index = i),
                  showNav: false,
                ),
                const CribsScreen(),
                const ActivityScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SolidBottomNav(
              currentIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
