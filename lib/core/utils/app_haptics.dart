import 'package:flutter/services.dart';

/// One vocabulary for tactile feedback across PayCal.
/// Keep selection feedback quiet; reserve stronger pulses for actions with
/// greater consequence so the app never feels noisy.
enum AppHapticStrength { none, soft, medium, harsh }

abstract final class AppHaptics {
  // Android vendors often suppress selectionClick entirely. A light impact is
  // still gentle, but is consistently felt on the onboarding pickers.
  static Future<void> soft() => HapticFeedback.lightImpact();

  static Future<void> medium() => HapticFeedback.mediumImpact();

  static Future<void> harsh() => HapticFeedback.heavyImpact();

  static Future<void> trigger(AppHapticStrength strength) => switch (strength) {
    AppHapticStrength.none => Future.value(),
    AppHapticStrength.soft => soft(),
    AppHapticStrength.medium => medium(),
    AppHapticStrength.harsh => harsh(),
  };
}
