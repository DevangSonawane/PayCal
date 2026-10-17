import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';

class GlassConfig {
  static bool enabled = true;
}

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = AppRadii.sheetTop,
    this.blur = 24,
    this.fillOpacity = 0.72,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double fillOpacity;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final useSolid =
        MediaQuery.highContrastOf(context) || !GlassConfig.enabled;

    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useSolid
            ? AppColors.surfaceRaised
            : AppColors.surfaceRaised.withValues(alpha: fillOpacity),
        borderRadius: shape,
        border: Border.all(color: AppColors.glassEdge, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.floatingShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (useSolid) return box;
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      ),
    );
  }
}
