import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';
import 'package:paycal/core/theme/app_typography.dart';

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPalette.current.ink, width: 1.5),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (i == selected) return;
                HapticFeedback.selectionClick();
                onSelect(i);
              },
              child: TweenAnimationBuilder<double>(
                // Re-mounts on each switch so the active pill pops.
                key: ValueKey(selected),
                tween: Tween(begin: 1.06, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppPalette.current.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: active ? Colors.white : AppPalette.current.grey,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
