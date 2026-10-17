import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/logger/logger_service.dart';
import 'core/notification/notification_service.dart';
import 'shared/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await LoggerService.init(prefs);
  try {
    await NotificationService().init();
  } catch (e) {
    LoggerService.sync('通知初始化失败，可在设置中重试: $e', isError: true);
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const App(),
    ),
  );
}
