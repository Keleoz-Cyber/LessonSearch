import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

ThemeData buildLightTheme() => _build(AppColors.light, Brightness.light);
ThemeData buildDarkTheme() => _build(AppColors.dark, Brightness.dark);

ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brandPrimary,
    onPrimary: c.onBrand,
    primaryContainer: c.brandSubtle,
    onPrimaryContainer: c.brandPrimary,
    secondary: c.brandPrimary,
    onSecondary: c.onBrand,
    error: c.stateDanger,
    onError: c.onBrand,
    surface: c.bgSurface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.bgMuted,
    onSurfaceVariant: c.textSecondary,
    outline: c.borderDefault,
    outlineVariant: c.borderSubtle,
  );

  final textTheme = TextTheme(
    displayLarge: AppTextStyles.display.copyWith(color: c.textPrimary),
    headlineMedium: AppTextStyles.h1.copyWith(color: c.textPrimary),
    headlineSmall: AppTextStyles.h2.copyWith(color: c.textPrimary),
    titleLarge: AppTextStyles.h2.copyWith(color: c.textPrimary),
    titleMedium: AppTextStyles.h3.copyWith(color: c.textPrimary),
    titleSmall: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
    bodyLarge: AppTextStyles.body.copyWith(color: c.textPrimary),
    bodyMedium: AppTextStyles.body.copyWith(color: c.textPrimary),
    bodySmall: AppTextStyles.sm.copyWith(color: c.textSecondary),
    labelLarge: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
    labelMedium: AppTextStyles.sm.copyWith(color: c.textSecondary),
    labelSmall: AppTextStyles.xs.copyWith(color: c.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bgCanvas,
    canvasColor: c.bgSurface,
    dividerColor: c.borderSubtle,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgCanvas,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.h1.copyWith(color: c.textPrimary),
      toolbarHeight: 52,
    ),
    cardTheme: CardThemeData(
      color: c.bgSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.brandPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.normal),
        borderSide: BorderSide(color: c.stateDanger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.bgElevated,
      contentTextStyle: AppTextStyles.body.copyWith(color: c.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      titleTextStyle: AppTextStyles.h2.copyWith(color: c.textPrimary),
      contentTextStyle: AppTextStyles.body.copyWith(color: c.textPrimary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    highlightColor: Colors.transparent,
  );
}
