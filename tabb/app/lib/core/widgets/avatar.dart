import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_radii.dart';
import 'package:paycal/core/theme/app_typography.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.size = 32,
    this.imageUrl,
    this.imageAsset,
  });

  final String initials;
  final double size;
  final String? imageUrl;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.tintBgFor(initials);
    final fg = AppColors.tintFgFor(initials);
    final image = imageAsset != null
        ? AssetImage(imageAsset!) as ImageProvider<Object>
        : imageUrl != null
        ? NetworkImage(imageUrl!)
        : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.avatar),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _AvatarWedgePainter(fg)),
                ),
                Center(
                  child: Text(
                    initials,
                    style: AppTypography.label.copyWith(color: fg),
                  ),
                ),
              ],
            )
          : Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Center(
                child: Text(
                  initials,
                  style: AppTypography.label.copyWith(color: fg),
                ),
              ),
            ),
    );
  }
}

class _AvatarWedgePainter extends CustomPainter {
  const _AvatarWedgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.42)
      ..lineTo(size.width * 0.58, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.35));
  }

  @override
  bool shouldRepaint(covariant _AvatarWedgePainter old) => old.color != color;
}

/// Overlapping member avatars with a 2px ring, per the component spec.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.initials,
    this.size = 32,
    this.max = 3,
  });

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
                  border: Border.all(color: AppPalette.current.bg, width: 2),
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
                  color: AppPalette.current.card,
                  borderRadius: BorderRadius.circular(AppRadii.avatar),
                  border: Border.all(color: AppPalette.current.bg, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: AppTypography.caption.copyWith(
                      color: AppPalette.current.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
