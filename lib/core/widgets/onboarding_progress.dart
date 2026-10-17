import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';

class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({super.key, required this.currentStep, this.totalSteps = 4});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final filled = index <= currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: filled ? AppColors.textPrimary : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadii.chipPill),
            ),
          ),
        );
      }),
    );
  }
}
