import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/widgets/glass_bottom_nav.dart';
import 'package:paycal/features/activity/activity_screen.dart';
import 'package:paycal/features/batches/batches_screen.dart';
import 'package:paycal/features/expenses/quick_add_sheet.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: const [HomeScreen(), BatchesScreen(), ActivityScreen(), ProfileScreen()],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomNav(
              currentIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              onAddPressed: () => showQuickAdd(context),
            ),
          ),
        ],
      ),
    );
  }
}
