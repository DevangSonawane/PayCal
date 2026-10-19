import 'package:flutter/material.dart';

/// Two bundled families:
///  - Bricolage Grotesque — characterful display face for numbers, titles and
///    anything that should feel like a sticker headline (up to w800).
///  - Space Grotesk — quirky-but-readable body face for everything small.
class AppTypography {
  static const String displayFamily = 'BricolageGrotesque';
  static const String bodyFamily = 'SpaceGrotesk';

  static const TextStyle displayAmount = TextStyle(
    fontSize: 44,
    height: 52 / 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    fontFamily: displayFamily,
  );
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    fontFamily: displayFamily,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    fontFamily: displayFamily,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    fontFamily: displayFamily,
  );
  static const TextStyle titleLg = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    fontFamily: displayFamily,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    fontFamily: displayFamily,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFamily: bodyFamily,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFamily: bodyFamily,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    fontFamily: bodyFamily,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    fontFamily: bodyFamily,
  );
  static const TextStyle amount = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFamily: displayFamily,
  );
}
