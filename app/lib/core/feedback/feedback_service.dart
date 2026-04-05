import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackService {
  static const _keyVibration = 'feedback_vibration';
  static const _keySound = 'feedback_sound';

  final SharedPreferences _prefs;

  FeedbackService(this._prefs);

  bool get vibrationEnabled => _prefs.getBool(_keyVibration) ?? true;
  bool get soundEnabled => _prefs.getBool(_keySound) ?? false;

  Future<void> setVibration(bool enabled) async {
    await _prefs.setBool(_keyVibration, enabled);
  }

  Future<void> setSound(bool enabled) async {
    await _prefs.setBool(_keySound, enabled);
  }

  void feedback() {
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void mediumFeedback() {
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void heavyFeedback() {
    if (vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void selectionFeedback() {
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
