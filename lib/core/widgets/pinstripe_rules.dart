import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';

/// The signature ruled-paper texture: 1px ink pinstripes every 6px over the
/// top [height] px of the canvas, fading out past 58% of that band.
class PinstripePainter extends CustomPainter {
  const PinstripePainter({this.height = 180, this.opacity = 0.045});

  final double height;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final band = math.min(size.height, height);
    final fadeAt = band * 0.58;
    final paint = Paint()..strokeWidth = 1;
    for (var y = 0.0; y < band; y += 6) {
      final t = y < fadeAt ? 1.0 : 1.0 - (y - fadeAt) / (band - fadeAt);
      paint.color = AppPalette.current.ink.withValues(alpha: opacity * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
