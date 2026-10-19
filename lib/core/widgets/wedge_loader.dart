import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';

/// A spinning lime pie-wedge with an ink outline — the house loading spinner.
class WedgeLoader extends StatefulWidget {
  const WedgeLoader({super.key, this.size = 30});

  final double size;

  @override
  State<WedgeLoader> createState() => _WedgeLoaderState();
}

class _WedgeLoaderState extends State<WedgeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.rotate(
        angle: _controller.value * 6.28318,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _WedgePainter(),
        ),
      ),
    );
  }
}

class _WedgePainter extends CustomPainter {
  _WedgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final gap = 1.1;
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -gap / 2,
        6.28318 - gap,
        false,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppPalette.current.lime
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppPalette.current.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small ink wedge used as a bullet in front of section headings.
class WedgeBullet extends StatelessWidget {
  const WedgeBullet({super.key, this.color, this.size = 10});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WedgeBulletPainter(color ?? AppPalette.current.ink),
    );
  }
}

class _WedgeBulletPainter extends CustomPainter {
  const _WedgeBulletPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WedgeBulletPainter old) => old.color != color;
}
