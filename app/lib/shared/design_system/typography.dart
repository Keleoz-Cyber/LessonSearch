import 'package:flutter/material.dart';

class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle sm = TextStyle(
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle xs = TextStyle(
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
  );

  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle withTabular(TextStyle base) =>
      base.copyWith(fontFeatures: tabular);
}
