import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData light() {
    const textTheme = TextTheme(
      displayLarge: AppTypography.displayAmount,
      displayMedium: AppTypography.display,
      displaySmall: AppTypography.headline,
      headlineMedium: AppTypography.title,
      headlineSmall: AppTypography.titleSmall,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.amount,
      labelLarge: AppTypography.label,
      labelSmall: AppTypography.caption,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.current.bg,
      colorScheme: ColorScheme.light(
        surface: AppPalette.current.bg,
        primary: AppPalette.current.text,
        onPrimary: AppColors.onPrimary,
        secondary: AppPalette.current.textSecondary,
        error: AppPalette.current.oweText,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.current.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppPalette.current.text,
        centerTitle: true,
      ),
      dividerColor: AppPalette.current.border,
    );
  }

  static ThemeData dark() {
    const textTheme = TextTheme(
      displayLarge: AppTypography.displayAmount,
      displayMedium: AppTypography.display,
      displaySmall: AppTypography.headline,
      headlineMedium: AppTypography.title,
      headlineSmall: AppTypography.titleSmall,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.amount,
      labelLarge: AppTypography.label,
      labelSmall: AppTypography.caption,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.dark.page,
      colorScheme: ColorScheme.dark(
        surface: AppPalette.dark.surface,
        surfaceContainerHighest: AppPalette.dark.card,
        primary: AppPalette.dark.ink,
        onPrimary: AppPalette.dark.page,
        secondary: AppPalette.dark.textSecondary,
        outline: AppPalette.dark.border,
        error: AppPalette.dark.oweText,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppPalette.dark.text,
        displayColor: AppPalette.dark.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.dark.page,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppPalette.dark.text,
        centerTitle: true,
      ),
      dividerColor: AppPalette.dark.border,
      cardTheme: CardThemeData(
        color: AppPalette.dark.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppPalette.dark.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppPalette.dark.surface,
        modalBackgroundColor: AppPalette.dark.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.dark.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppPalette.dark.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.dark.card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppPalette.dark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppPalette.dark.pink, width: 2),
        ),
      ),
    );
  }
}
