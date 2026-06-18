import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xl2 = 32;
  static const double xl3 = 48;
}

class AppRadius {
  static const double none = 0;
  static const double sm = 4;
  static const double normal = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double full = 999;
}

class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}

class AppCurves {
  static const Curve fast = Curves.easeOut;
  static const Curve normal = Curves.easeInOut;
}

class AppMinTouchSize {
  static const double width = 44;
  static const double height = 44;
}
