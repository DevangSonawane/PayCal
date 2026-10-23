import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';

/// Draws a hand-drawn pink squiggle under its child, like a marker swipe.
class SquigglyUnderline extends StatelessWidget {
  const SquigglyUnderline({
    super.key,
    required this.child,
    this.color,
    this.amplitude = 3.5,
    this.wavelength = 14,
  });

  final Widget child;
  final Color? color;
  final double amplitude;
  final double wavelength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SquigglePainter(
        color: color ?? AppPalette.current.pink,
        amplitude: amplitude,
        wavelength: wavelength,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: amplitude + 3),
        child: child,
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter({
    required this.color,
    required this.amplitude,
    required this.wavelength,
  });

  final Color color;
  final double amplitude;
  final double wavelength;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final baseY = size.height - amplitude;
    for (var x = 0.0; x <= size.width; x += 0.5) {
      final y = baseY + amplitude * math.sin((x / wavelength) * math.pi * 2);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SquigglePainter old) =>
      old.color != color ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength;
}

/// Paints a slightly skewed lime highlighter swipe behind the child text.
class MarkerHighlight extends StatelessWidget {
  const MarkerHighlight({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MarkerPainter(color: color ?? AppPalette.current.lime),
      child: child,
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.018);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width + 10,
      height: size.height * 0.82,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) => old.color != color;
}
