import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/logger/logger_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 应用启动时调用一次
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      LoggerService.sync('Notification: 时区获取失败 $e', isError: true);
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 请求通知权限（用户首次启用提醒时调用）
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      final exactAlarm = await android.requestExactAlarmsPermission() ?? false;
      return granted && exactAlarm;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return false;
  }

  Future<bool> isPermissionGranted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// 调度一条查课提醒
  ///
  /// [scheduledAt] 必须是未来时间。
  /// 时间已过则跳过（返回 false）。
  Future<bool> scheduleDutyReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (scheduledAt.isBefore(DateTime.now())) {
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'duty_reminder',
      '查课提醒',
      channelDescription: '上课前 15 分钟提醒查课',
      importance: Importance.high,
      priority: Priority.high,
      ticker: '查课提醒',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzTime = tz.TZDateTime.from(scheduledAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return true;
    } catch (e) {
      LoggerService.sync('Notification: 调度失败 $e', isError: true);
      return false;
    }
  }

  Future<void> cancel(int notificationId) async {
    if (!_initialized) await init();
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAll() async {
    if (!_initialized) await init();
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pendingRequests() async {
    if (!_initialized) await init();
    return _plugin.pendingNotificationRequests();
  }
}
