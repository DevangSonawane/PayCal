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

  static const Color owedText = Color(0xFF2F6F52);
  static const Color owedTint = Color(0xFFE9F2EC);
  static const Color oweText = Color(0xFFA4472F);
  static const Color oweTint = Color(0xFFF7EBE6);
  static const Color pendingText = Color(0xFF845A10);
  static const Color pendingTint = Color(0xFFFAF2E1);
  static const Color infoText = Color(0xFF385878);
  static const Color infoTint = Color(0xFFE9EFF5);

  // Black at 24% for scrim, 8% for glass edge, 6% shadow.
  static const Color scrim = Color(0x3D000000);
  static const Color glassEdge = Color(0x14000000);
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
