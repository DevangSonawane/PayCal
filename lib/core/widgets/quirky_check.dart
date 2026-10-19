import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_motion.dart';

/// Hand-drawn feel: a slightly wobbly ring that, when selected, gets an
/// ink dot with a marker-stroke tick popping in with a springy overshoot.
class QuirkyCheck extends StatelessWidget {
  const QuirkyCheck({super.key, required this.selected, this.size = 24});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(selected ? AppPalette.current.ink : AppPalette.current.grey),
            ),
          ),
          Positioned.fill(
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: AppMotion.base,
              curve: Curves.easeOutBack,
              child: CustomPaint(painter: const _TickPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

/// A circle that isn't *quite* perfect — four cubic segments with tiny
/// deterministic wobbles so it feels drawn by hand.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1;
    const wobble = 0.055;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a0 = i * math.pi / 2;
      final a1 = (i + 1) * math.pi / 2;
      final p0 = Offset(c.dx + r * math.cos(a0), c.dy + r * math.sin(a0));
      final p1 = Offset(c.dx + r * math.cos(a1), c.dy + r * math.sin(a1));
      final w1 = r * (1 + (i.isEven ? wobble : -wobble));
      final w2 = r * (1 + (i.isEven ? -wobble : wobble));
      final k = 0.5523;
      final c1 = Offset(
        c.dx + w1 * k * math.cos(a0 + math.pi / 4),
        c.dy + w1 * k * math.sin(a0 + math.pi / 4),
      );
      final c2 = Offset(
        c.dx + w2 * k * math.cos(a1 - math.pi / 4),
        c.dy + w2 * k * math.sin(a1 - math.pi / 4),
      );
      if (i == 0) path.moveTo(p0.dx, p0.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.color != color;
}

/// Ink disc with a marker-stroke tick that overshoots the edge a touch.
class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = AppPalette.current.ink);
    final tick = Path()
      ..moveTo(size.width * 0.27, size.height * 0.52)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.68,
        size.width * 0.52,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.54,
        size.width * 0.78,
        size.height * 0.30,
      );
    canvas.drawPath(
      tick,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppPalette.current.lime,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
