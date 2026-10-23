import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paycal/core/utils/party_mode.dart';
import 'package:paycal/core/widgets/confetti_burst.dart';

/// Wrap a widget to make a triple-tap (within 800ms) toggle party mode,
/// with confetti and a toast-free haptic fanfare.
class PartyTap extends StatefulWidget {
  const PartyTap({super.key, required this.child});

  final Widget child;

  @override
  State<PartyTap> createState() => _PartyTapState();
}

class _PartyTapState extends State<PartyTap> {
  int _taps = 0;
  Timer? _window;

  void _handle() {
    HapticFeedback.selectionClick();
    _taps++;
    _window?.cancel();
    if (_taps >= 3) {
      _taps = 0;
      PartyMode.instance.toggle();
      if (PartyMode.instance.isOn && mounted) {
        showConfettiBurst(context, count: 44);
      } else {
        HapticFeedback.lightImpact();
      }
      return;
    }
    _window = Timer(const Duration(milliseconds: 800), () => _taps = 0);
  }

  @override
  void dispose() {
    _window?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handle,
      child: widget.child,
    );
  }
}
