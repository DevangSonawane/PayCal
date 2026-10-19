import 'package:flutter/material.dart';

/// Wraps a tappable child and squishes it to 96% while pressed, then springs
/// back with a cheeky overshoot. Uses a Listener so it never steals taps from
/// the child's own gesture arena.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.downScale = 0.96});

  final Widget child;
  final double downScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.downScale : 1,
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 340),
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
