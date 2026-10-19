import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';
import 'package:paycal/core/theme/app_typography.dart';
import 'package:paycal/core/widgets/confetti_burst.dart';

/// Animated quirky "all set" sticker that pops over the screen together with a
/// confetti burst, wobbles like a slapped-on sticker, then flies off.
/// Fire after any successful action (payment recorded, expense added, ...).
void showQuirkyConfirm(BuildContext context, String text) {
  showConfettiBurst(context);
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _QuirkyConfirm(text: text, onDone: entry.remove),
    ),
  );
  overlay.insert(entry);
}

class _QuirkyConfirm extends StatefulWidget {
  const _QuirkyConfirm({required this.text, required this.onDone});

  final String text;
  final VoidCallback onDone;

  @override
  State<_QuirkyConfirm> createState() => _QuirkyConfirmState();
}

class _QuirkyConfirmState extends State<_QuirkyConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward().whenComplete(widget.onDone);
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
      builder: (context, _) {
        final t = _controller.value;
        final pop = Curves.easeOutBack.transform((t / 0.28).clamp(0.0, 1.0));
        final out = Curves.easeInCubic.transform(
          ((t - 0.82) / 0.18).clamp(0.0, 1.0),
        );
        final wobble = math.sin(t * math.pi * 6) * 0.05 * (1 - t);
        return Align(
          alignment: const Alignment(0, -0.32),
          child: Opacity(
            opacity: (1 - out).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, out * -50),
              child: Transform.rotate(
                angle: -6 * math.pi / 180 + wobble,
                child: Transform.scale(
                  scale: pop * (1 - out * 0.5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.current.lime,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppPalette.current.ink,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.floatingShadow,
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.text.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.current.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
