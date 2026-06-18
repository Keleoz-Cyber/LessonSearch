import 'package:flutter/material.dart';

class AppColors {
  final Color bgCanvas;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgMuted;

  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  final Color brandPrimary;
  final Color brandGradientFrom;
  final Color brandGradientTo;
  final Color brandSubtle;
  final Color onBrand;

  final Color stateSuccess;
  final Color stateWarning;
  final Color stateDanger;
  final Color stateInfo;

  const AppColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgMuted,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.brandPrimary,
    required this.brandGradientFrom,
    required this.brandGradientTo,
    required this.brandSubtle,
    required this.onBrand,
    required this.stateSuccess,
    required this.stateWarning,
    required this.stateDanger,
    required this.stateInfo,
  });

  static const light = AppColors(
    bgCanvas: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFFFFFFF),
    bgMuted: Color(0xFFF4F4F5),
    borderSubtle: Color(0xFFE4E4E7),
    borderDefault: Color(0xFFD4D4D8),
    borderStrong: Color(0xFFA1A1AA),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFF71717A),
    textDisabled: Color(0xFFA1A1AA),
    brandPrimary: Color(0xFF2563EB),
    brandGradientFrom: Color(0xFF38BDF8),
    brandGradientTo: Color(0xFF2563EB),
    brandSubtle: Color(0xFFEFF6FF),
    onBrand: Color(0xFFFFFFFF),
    stateSuccess: Color(0xFF059669),
    stateWarning: Color(0xFFD97706),
    stateDanger: Color(0xFFDC2626),
    stateInfo: Color(0xFF0EA5E9),
  );

  static const dark = AppColors(
    bgCanvas: Color(0xFF0A0A0B),
    bgSurface: Color(0xFF18181B),
    bgElevated: Color(0xFF27272A),
    bgMuted: Color(0xFF27272A),
    borderSubtle: Color(0xFF27272A),
    borderDefault: Color(0xFF3F3F46),
    borderStrong: Color(0xFF52525B),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    textDisabled: Color(0xFF52525B),
    brandPrimary: Color(0xFF60A5FA),
    brandGradientFrom: Color(0xFF7DD3FC),
    brandGradientTo: Color(0xFF60A5FA),
    brandSubtle: Color(0x4D1E3A8A),
    onBrand: Color(0xFF0A0A0B),
    stateSuccess: Color(0xFF10B981),
    stateWarning: Color(0xFFF59E0B),
    stateDanger: Color(0xFFEF4444),
    stateInfo: Color(0xFF38BDF8),
  );

  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandGradientFrom, brandGradientTo],
      );
}

extension AppColorsExt on BuildContext {
  AppColors get colors {
    final brightness = Theme.of(this).brightness;
    return brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  }
}
