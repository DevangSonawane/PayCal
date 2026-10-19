import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/theme/app_colors.dart';

/// Fires a one-shot burst of geometric confetti (wedges, dots and bars in the
/// brand accents) from the middle of the screen. Includes a medium haptic.
void showConfettiBurst(
  BuildContext context, {
  int count = 30,
  double gravity = 420,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  HapticFeedback.mediumImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiBurst(
        count: count,
        gravity: gravity,
        onDone: entry.remove,
      ),
    ),
  );
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({
    required this.count,
    required this.gravity,
    required this.onDone,
  });

  final int count;
  final double gravity;
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Shard> _shards;

  static const _palette = [
    AppPalette.current.lime,
    AppPalette.current.pink,
    AppPalette.current.purple,
    AppColors.indigo,
    AppPalette.current.ink,
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _shards = List.generate(widget.count, (i) {
      final angle = -math.pi * (0.12 + rng.nextDouble() * 0.76);
      return _Shard(
        angle: angle,
        speed: 140 + rng.nextDouble() * 240,
        size: 6 + rng.nextDouble() * 9,
        color: _palette[i % _palette.length],
        shape: _Shape.values[rng.nextInt(_Shape.values.length)],
        spin: (rng.nextDouble() - 0.5) * 10,
        delay: rng.nextDouble() * 0.18,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(
            progress: _controller.value,
            shards: _shards,
            gravity: widget.gravity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

enum _Shape { dot, bar, wedge }

class _Shard {
  const _Shard({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.shape,
    required this.spin,
    required this.delay,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final _Shape shape;
  final double spin;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.progress,
    required this.shards,
    required this.gravity,
  });

  final double progress;
  final List<_Shard> shards;
  final double gravity;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    for (final s in shards) {
      final t = ((progress - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final ease = Curves.easeOut.transform(t);
      final dx = math.cos(s.angle) * s.speed * ease;
      final dy = math.sin(s.angle) * s.speed * ease + gravity * t * t;
      final alpha = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
      final paint = Paint()
        ..color = s.color.withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(s.spin * t);
      switch (s.shape) {
        case _Shape.dot:
          canvas.drawCircle(Offset.zero, s.size / 2, paint);
        case _Shape.bar:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: s.size * 1.8,
                height: s.size * 0.7,
              ),
              const Radius.circular(3),
            ),
            paint,
          );
        case _Shape.wedge:
          final path = Path()
            ..moveTo(0, -s.size)
            ..lineTo(s.size, s.size)
            ..lineTo(-s.size, s.size)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.gravity != gravity;
}
