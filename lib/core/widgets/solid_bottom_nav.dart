import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/utils/app_haptics.dart';

const _navItems = [
  (Icons.home_outlined, Icons.home_rounded, 'Home'),
  (Icons.groups_outlined, Icons.groups_rounded, 'Batches'),
  (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Activity'),
  (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

/// Signature floating bottom nav: white pill, heavy ink border, selected tab
/// lights up as a lime circle like the ink dots used across the app.
class SolidBottomNav extends StatelessWidget {
  const SolidBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          // Keep the original warm page-colour nav in light mode; dark mode
          // alone uses a raised card surface to avoid blending into the page.
          color: Theme.of(context).brightness == Brightness.dark
              ? AppPalette.current.card
              : AppPalette.current.page,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppPalette.current.ink, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _navItems.length; i++)
              Expanded(
                child: Semantics(
                  label: _navItems[i].$3,
                  button: true,
                  selected: currentIndex == i,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == currentIndex) return;
                      // Navigation is a major context change; selectionClick is
                      // nearly imperceptible on many Android devices.
                      AppHaptics.medium();
                      onDestinationSelected(i);
                    },
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NavDot(selected: currentIndex == i, index: i),
                          const SizedBox(height: 3),
                          Text(
                            _navItems[i].$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppPalette.current.ink,
                              fontWeight: currentIndex == i
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NavDot extends StatelessWidget {
  const _NavDot({required this.selected, required this.index});
  final bool selected;
  final int index;

  @override
  Widget build(BuildContext c) => AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutBack,
    width: selected ? 40 : 40,
    height: 40,
    decoration: selected
        ? BoxDecoration(
            color: AppPalette.current.lime,
            shape: BoxShape.circle,
            border: Border.all(color: AppPalette.current.ink, width: 2),
          )
        : null,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          selected ? _navItems[index].$2 : _navItems[index].$1,
          color: selected ? AppPalette.current.ink : AppPalette.current.grey,
          size: 24,
        ),
        if (index == 3 && !selected)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppPalette.current.pink,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.current.page, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}
