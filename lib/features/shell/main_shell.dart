import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/utils/deep_link.dart';
import 'package:paycal/core/widgets/solid_bottom_nav.dart';
import 'package:paycal/features/activity/activity_screen.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    DeepLinks.listen(Navigator.of(context));
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
