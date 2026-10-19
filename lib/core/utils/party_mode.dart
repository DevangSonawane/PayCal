import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paycal/core/theme/app_colors.dart';

/// Easter egg state: triple-tap the profile identity card to start a
/// party — the nav pill and identity card cycle through the accent palette
/// until toggled off. Session-only, never persisted.
class PartyMode extends ChangeNotifier {
  PartyMode._();
  static final PartyMode instance = PartyMode._();

  static const List<Color> palette = [
    AppColors.indigo,
    AppPalette.current.pink,
    AppPalette.current.purple,
    AppPalette.current.teal,
    AppColors.brick,
  ];

  bool _on = false;
  int _tick = 0;
  Timer? _timer;

  bool get isOn => _on;

  Color get accent => _on ? palette[_tick % palette.length] : AppColors.indigo;

  Color get identityCard =>
      _on ? palette[(_tick + 1) % palette.length] : AppPalette.current.purple;

  void toggle() {
    _on = !_on;
    if (_on) {
      _timer = Timer.periodic(const Duration(milliseconds: 950), (_) {
        _tick++;
        notifyListeners();
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _tick = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
