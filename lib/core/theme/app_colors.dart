import 'package:flutter/material.dart';

/// Design tokens — section 3.1. Only place where raw hex is allowed.
class AppColors {
  static const Color bg = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F5);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFECECE8);
  static const Color borderStrong = Color(0xFFD9D9D4);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF5F5F5B);
  static const Color textTertiary = Color(0xFF767672);
  static const Color textDisabled = Color(0xFFB8B8B3);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Signature design-language tokens (off-white page, ink borders, bold accents).
  static const Color ink = Color(0xFF0A0A0A);
  static const Color page = Color(0xFFFFFEFC);
  static const Color lime = Color(0xFFD8FF00);
  static const Color pink = Color(0xFFF0477F);
  static const Color purple = Color(0xFF9B70F2);
  static const Color indigo = Color(0xFF2014B8);
  static const Color teal = Color(0xFF0E7C66);
  static const Color brick = Color(0xFFB8321E);
  static const Color grey = Color(0xFF8A8A8A);
  static const Color chip = Color(0xFFF1F1F4);
  static const Color hairline = Color(0xFFE6E6EA);

  static const Color owedText = Color(0xFF2F6F52);
  static const Color owedTint = Color(0xFFE9F2EC);
  static const Color oweText = Color(0xFFA4472F);
  static const Color oweTint = Color(0xFFF7EBE6);
  static const Color pendingText = Color(0xFF845A10);
  static const Color pendingTint = Color(0xFFFAF2E1);
  static const Color infoText = Color(0xFF385878);
  static const Color infoTint = Color(0xFFE9EFF5);

  // Black at 24% for scrim and 6% shadow.
  static const Color scrim = Color(0x3D000000);
  static const Color floatingShadow = Color(0x0F000000);

  static const List<String> tintNames = [
    'sage',
    'sand',
    'clay',
    'sky',
    'lilac',
    'stone',
  ];

  static const Map<String, Color> tintBg = {
    'sage': Color(0xFFE9F0EA),
    'sand': Color(0xFFF4EEE2),
    'clay': Color(0xFFF6E9E4),
    'sky': Color(0xFFE7EEF5),
    'lilac': Color(0xFFEEEAF4),
    'stone': Color(0xFFEEEEEC),
  };
  static const Map<String, Color> tintFg = {
    'sage': Color(0xFF2F5D45),
    'sand': Color(0xFF7A5C1E),
    'clay': Color(0xFF8F4430),
    'sky': Color(0xFF355A7D),
    'lilac': Color(0xFF5B4A7D),
    'stone': Color(0xFF4A4A47),
  };

  static Color tintBgFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) % 997;
    }
    final name = tintNames[h % tintNames.length];
    return tintBg[name]!;
  }

  static Color tintFgFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) % 997;
    }
    final name = tintNames[h % tintNames.length];
    return tintFg[name]!;
  }
}

/// Brightness-aware semantic palette. Screens and widgets read
/// `AppPalette.current` so a dark-mode switch repaints everything at once.
@immutable
class AppPalette {
  const AppPalette({
    required this.page,
    required this.ink,
    required this.lime,
    required this.pink,
    required this.purple,
    required this.grey,
    required this.chip,
    required this.hairline,
    required this.border,
    required this.bg,
    required this.surface,
    required this.card,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.owedText,
    required this.oweText,
    required this.owedTint,
    required this.oweTint,
    required this.pendingText,
    required this.pendingTint,
    required this.teal,
    required this.scrim,
  });

  final Color page;
  final Color ink;
  final Color lime;
  final Color pink;
  final Color purple;
  final Color grey;
  final Color chip;
  final Color hairline;
  final Color border;
  final Color bg;
  final Color surface;
  final Color card;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color owedText;
  final Color oweText;
  final Color owedTint;
  final Color oweTint;
  final Color pendingText;
  final Color pendingTint;
  final Color teal;
  final Color scrim;

  static const light = AppPalette(
    page: Color(0xFFFFFEFC),
    ink: Color(0xFF0A0A0A),
    lime: Color(0xFFD8FF00),
    pink: Color(0xFFF0477F),
    purple: Color(0xFF9B70F2),
    grey: Color(0xFF8A8A8A),
    chip: Color(0xFFF1F1F4),
    hairline: Color(0xFFE6E6EA),
    border: Color(0xFFECECE8),
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F7F5),
    card: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
    textSecondary: Color(0xFF5F5F5B),
    textTertiary: Color(0xFF767672),
    owedText: Color(0xFF2F6F52),
    oweText: Color(0xFFA4472F),
    owedTint: Color(0xFFE9F2EC),
    oweTint: Color(0xFFF7EBE6),
    pendingText: Color(0xFF845A10),
    pendingTint: Color(0xFFFAF2E1),
    teal: Color(0xFF0E7C66),
    scrim: Color(0x3D000000),
  );

  static const dark = AppPalette(
    // Layered, blue-charcoal surfaces make hierarchy visible without relying
    // on pure black cards. The values step up in luminance like native dark
    // interfaces: canvas → page → raised surface → card/input.
    page: Color(0xFF101317),
    ink: Color(0xFFF4F7FA),
    lime: Color(0xFFD7F75C),
    pink: Color(0xFFFF7AA8),
    purple: Color(0xFFB9A0FF),
    grey: Color(0xFFAAB2BB),
    chip: Color(0xFF30363E),
    hairline: Color(0xFF3B444E),
    border: Color(0xFF3B444E),
    bg: Color(0xFF15191E),
    surface: Color(0xFF1D2228),
    card: Color(0xFF252C33),
    text: Color(0xFFF4F7FA),
    textSecondary: Color(0xFFC3CBD4),
    textTertiary: Color(0xFF98A2AD),
    owedText: Color(0xFF8BE39B),
    oweText: Color(0xFFFF9EB8),
    owedTint: Color(0xFF193726),
    oweTint: Color(0xFF44212C),
    pendingText: Color(0xFFF1D274),
    pendingTint: Color(0xFF39331D),
    teal: Color(0xFF63D8BA),
    scrim: Color(0x99000000),
  );

  static AppPalette current = light;
}
