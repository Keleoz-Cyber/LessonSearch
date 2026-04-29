import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoggerService {
  static const _key = 'debug_logs';
  static const _maxLogs = 200;

  static SharedPreferences? _prefs;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  static void log(String msg, {String tag = 'App', bool isError = false}) {
    final ts = DateTime.now().toString().substring(11, 19);
    final log = '[$ts] [$tag] ${isError ? "\u274c " : ""}$msg';

    debugPrint(log);

    if (_prefs == null) return;

    final logs = _prefs!.getStringList(_key) ?? [];
    logs.insert(0, log);
    if (logs.length > _maxLogs) logs.removeRange(_maxLogs, logs.length);
    _prefs!.setStringList(_key, logs);
  }

  static void sync(String msg, {bool isError = false}) =>
      log(msg, tag: 'Sync', isError: isError);

  static void network(String msg, {bool isError = false}) =>
      log(msg, tag: 'Net', isError: isError);

  static void error(String msg, {String tag = 'Error'}) =>
      log(msg, tag: tag, isError: true);

  static List<String> getLogs() {
    return _prefs?.getStringList(_key) ?? [];
  }

  static Future<void> clear() async {
    await _prefs?.remove(_key);
  }
}
