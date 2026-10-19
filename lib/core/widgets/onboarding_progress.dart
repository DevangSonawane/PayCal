import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    this.accent = AppPalette.current.pink,
  });

  final int currentStep;
  final int totalSteps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final color = index < currentStep
            ? AppPalette.current.ink
            : index == currentStep
            ? accent
            : AppPalette.current.chip;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            height: 7,
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.chipPill),
            ),
          ),
        );
      }),
    );
  }
}
