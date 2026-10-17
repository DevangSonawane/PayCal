import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_typography.dart';

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.size = 32});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.tintBgFor(initials);
    final fg = AppColors.tintFgFor(initials);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.avatar)),
      child: Center(
        child: Text(initials, style: AppTypography.label.copyWith(color: fg)),
      ),
    );
  }
}

/// Overlapping member avatars with a 2px ring, per the component spec.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.initials, this.size = 32, this.max = 3});

  final List<String> initials;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = initials.take(max).toList();
    final extra = initials.length - shown.length;
    return SizedBox(
      height: size,
      width: size + (shown.length - 1 + (extra > 0 ? 1 : 0)) * (size - 8),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.avatar),
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: Avatar(initials: shown[i], size: size - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (size - 8),
              child: Container(
                width: size - 4,
                height: size - 4,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.avatar),
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: Center(child: Text('+$extra', style: AppTypography.caption.copyWith(color: AppColors.textSecondary))),
              ),
            ),
        ],
      ),
    );
  }
}
