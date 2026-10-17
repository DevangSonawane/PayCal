import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width = 120, this.height = 16, this.radius = 12});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonParagraph extends StatelessWidget {
  const SkeletonParagraph({super.key, this.maxLines = 3, this.width = 200});

  final int maxLines;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
