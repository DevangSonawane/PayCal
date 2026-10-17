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
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        surface: AppColors.bg,
        primary: AppColors.textPrimary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.textSecondary,
        error: AppColors.oweText,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      dividerColor: AppColors.border,
    );
  }
}
