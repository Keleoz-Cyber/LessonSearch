import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import '../../features/duty_plan/data/duty_plan_repository.dart';
import '../../features/duty_plan/domain/duty_plan.dart';
import '../logger/logger_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class ReminderScheduleResult {
  final String status;
  final String? error;
  const ReminderScheduleResult(this.status, [this.error]);
  bool get isScheduled =>
      status == 'scheduledExact' || status == 'scheduledInexact';
  String get message => switch (status) {
    'scheduledExact' => '已安排上课前 15 分钟提醒',
    'scheduledInexact' => '已安排系统提醒，未允许精确提醒时可能延迟',
    'permissionDenied' => '计划已保存，请开启通知权限后恢复提醒',
    'elapsed' => '计划已保存，提醒时间已过，本次不会再提醒',
    'unsupported' => '计划已保存，当前平台暂不支持提醒',
    'disabled' => '提醒已关闭',
    _ => '计划已保存，提醒设置失败，请在通知设置中重试',
  };
}

class NotificationPermissionState {
  final bool supported;
  final bool notificationsEnabled;
  final bool exactAlarms;
  final bool liveUpdatesSupported;
  final bool liveUpdatesEnabled;
  const NotificationPermissionState({
    required this.supported,
    required this.notificationsEnabled,
    this.exactAlarms = false,
    this.liveUpdatesSupported = false,
    this.liveUpdatesEnabled = false,
  });
}

/// OS-owned Android alarms and iOS UNUserNotificationCenter requests.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel channel = const MethodChannel('lesson_search/notifications'),
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = channel,
       _platform = platform;

  @visibleForTesting
  factory NotificationService.forTesting({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel channel = const MethodChannel('lesson_search/notifications'),
    TargetPlatform? platform,
  }) => NotificationService._(
    plugin: plugin,
    channel: channel,
    platform: platform,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;
  final TargetPlatform? _platform;
  final ValueNotifier<String?> openPayload = ValueNotifier(null);
  bool _initialized = false;
  Future<void>? _initializing;
  Future<void> _work = Future.value();
  bool get _android =>
      !kIsWeb && (_platform ?? defaultTargetPlatform) == TargetPlatform.android;
  bool get _ios =>
      !kIsWeb && (_platform ?? defaultTargetPlatform) == TargetPlatform.iOS;

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _work.then((_) => action());
    _work = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<void> init() async {
    if (_initialized) return;
    await (_initializing ??= _initialize());
  }

  Future<void> _initialize() async {
    try {
      if (!_android && !_ios) {
        _initialized = true;
        return;
      }
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()),
        );
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      }
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_check'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) openPayload.value = response.payload;
        },
      );
      if (_android) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'openPayload' && call.arguments is String) {
            openPayload.value = call.arguments as String;
          }
        });
        final payload = await _channel.invokeMethod<String>(
          'consumeLaunchPayload',
        );
        if (payload != null) openPayload.value = payload;
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('native_reminders_migrated') ?? false)) {
          await _plugin.cancelAll();
          await prefs.setBool('native_reminders_migrated', true);
        }
        await _channel.invokeMethod<void>('restoreReminders');
      } else {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (launch?.didNotificationLaunchApp == true && payload != null) {
          openPayload.value = payload;
        }
      }
      _initialized = true;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<NotificationPermissionState> permissionState() async {
    if (!_android && !_ios) {
      return const NotificationPermissionState(
        supported: false,
        notificationsEnabled: false,
      );
    }
    await init();
    if (_android) {
      final data =
          await _channel.invokeMapMethod<String, dynamic>('permissionState') ??
          {};
      return NotificationPermissionState(
        supported: true,
        notificationsEnabled: data['notificationsEnabled'] == true,
        exactAlarms: data['exactAlarms'] == true,
        liveUpdatesSupported: data['liveUpdatesSupported'] == true,
        liveUpdatesEnabled: data['liveUpdatesEnabled'] == true,
      );
    }
    final permissions = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    return NotificationPermissionState(
      supported: true,
      notificationsEnabled:
          permissions?.isEnabled == true ||
          permissions?.isProvisionalEnabled == true,
      exactAlarms: true,
    );
  }

  Future<bool> isPermissionGranted() async =>
      (await permissionState()).notificationsEnabled;
  Future<bool> requestPermission() async {
    await init();
    if (_android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (_ios) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> requestExactPermission() async {
    await init();
    if (!_android) return _ios;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  Future<void> openSettings({String kind = 'notifications'}) async {
    await init();
    if (_android) {
      await _channel.invokeMethod<void>('openSettings', {'kind': kind});
    } else if (_ios) {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }

  Future<ReminderScheduleResult> scheduleDutyReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    if (!_android && !_ios) return const ReminderScheduleResult('unsupported');
    try {
      await init();
      if (!scheduledAt.isAfter(DateTime.now())) {
        await _cancel(notificationId);
        return const ReminderScheduleResult('elapsed');
      }
      if (_android) {
        final result =
            await _channel
                .invokeMapMethod<String, dynamic>('scheduleReminder', {
                  'id': notificationId,
                  'title': title,
                  'body': body,
                  'scheduledAt': scheduledAt.millisecondsSinceEpoch,
                  'payload': payload ?? '',
                }) ??
            {};
        return ReminderScheduleResult(
          result['status'] as String? ?? 'failed',
          result['error'] as String?,
        );
      }
      if (!await isPermissionGranted()) {
        return const ReminderScheduleResult('permissionDenied');
      }
      final pending = await _plugin.pendingNotificationRequests();
      if (pending.length >= 60 &&
          !pending.any((item) => item.id == notificationId)) {
        return const ReminderScheduleResult('failed', '系统待发送提醒已达上限，下次打开应用继续安排');
      }
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledAt, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return const ReminderScheduleResult('scheduledExact');
    } catch (e) {
      LoggerService.sync('通知调度失败: $e', isError: true);
      return ReminderScheduleResult('failed', e.toString());
    }
  }

  Future<ReminderScheduleResult> _schedulePlan(
    DutyPlanRepository repo,
    DutyPlan plan,
  ) async {
    if (!plan.reminderEnabled) {
      await _cancel(plan.notificationId);
      await repo.setReminderResult(plan.id, 'disabled');
      return const ReminderScheduleResult('disabled');
    }
    final result = await scheduleDutyReminder(
      notificationId: plan.notificationId,
      title:
          '查课提醒 · ${plan.periodLabel}${plan.classroom == null ? '' : ' @ ${plan.classroom}'}',
      body:
          '${plan.className ?? '查课计划'} · ${plan.weekdayLabel} ${plan.timeRange}',
      scheduledAt: plan.remindAt,
      payload: 'plan:${plan.id}',
    );
    await repo.setReminderResult(plan.id, result.status, result.error);
    return result;
  }

  Future<ReminderScheduleResult> syncPlan(
    DutyPlanRepository repo,
    String id, {
    bool requestPermissionIfNeeded = false,
  }) => _serial(() async {
    if (requestPermissionIfNeeded && !await isPermissionGranted()) {
      await requestPermission();
    }
    final plan = await repo.getById(id);
    if (plan == null) return const ReminderScheduleResult('failed', '计划不存在');
    return _schedulePlan(repo, plan);
  });
  Future<ReminderScheduleResult> setPlanEnabled(
    DutyPlanRepository repo,
    String id,
    bool enabled,
  ) => _serial(() async {
    final plan = await repo.getById(id);
    if (plan == null) return const ReminderScheduleResult('failed', '计划不存在');
    if (enabled && !await isPermissionGranted()) await requestPermission();
    final saved = await repo.upsert(
      plan.copyWith(reminderEnabled: enabled, reminderStatus: 'unknown'),
    );
    return _schedulePlan(repo, saved);
  });
  Future<void> deletePlan(DutyPlanRepository repo, String id) =>
      _serial(() async {
        final plan = await repo.getById(id);
        if (plan == null) return;
        await _cancel(plan.notificationId);
        await repo.delete(id);
      });

  Future<void> reconcile(DutyPlanRepository repo) => _serial(() async {
    await init();
    final plans = await repo.repairNotificationIds();
    var eligible = plans.where(
      (p) => p.reminderEnabled && p.remindAt.isAfter(DateTime.now()),
    );
    if (_ios) {
      eligible = eligible.take(60);
    }
    final wanted = eligible.map((p) => p.notificationId).toSet();
    for (final pending in await pendingRequests()) {
      if (!wanted.contains(pending.id)) await _cancel(pending.id);
    }
    for (final plan in plans) {
      if (_ios &&
          plan.reminderEnabled &&
          plan.remindAt.isAfter(DateTime.now()) &&
          !wanted.contains(plan.notificationId)) {
        await _cancel(plan.notificationId);
        await repo.setReminderResult(
          plan.id,
          'failed',
          '系统待发送提醒已达上限，下次打开应用继续安排',
        );
        continue;
      }
      await _schedulePlan(repo, plan);
    }
  });

  Future<void> _cancel(int id) async {
    await init();
    if (_android) {
      await _channel.invokeMethod<void>('cancelReminder', {'id': id});
    } else if (_ios) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancel(int id) => _serial(() => _cancel(id));
  Future<void> cancelAll() => _serial(() async {
    await init();
    if (_android) await _channel.invokeMethod<void>('cancelAll');
    if (_android || _ios) await _plugin.cancelAll();
    openPayload.value = null;
  });
  Future<List<PendingNotificationRequest>> pendingRequests() async {
    await init();
    if (_android) {
      final entries =
          await _channel.invokeListMethod<dynamic>('pendingReminders') ?? [];
      return entries.map((value) {
        final map = value as Map;
        return PendingNotificationRequest(
          map['id'] as int,
          map['title'] as String?,
          map['body'] as String?,
          map['payload'] as String?,
        );
      }).toList();
    }
    return _ios ? _plugin.pendingNotificationRequests() : [];
  }

  Future<bool> showAttendanceProgress({
    required String taskId,
    required String title,
    required int processed,
    required int total,
    bool requestPermissionIfNeeded = false,
  }) async {
    if (!_android) return false;
    try {
      await init();
      if (requestPermissionIfNeeded && !await isPermissionGranted()) {
        await requestPermission();
      }
      return await _channel.invokeMethod<bool>('showProgress', {
            'taskId': taskId,
            'title': title,
            'processed': processed,
            'total': total,
          }) ??
          false;
    } catch (e) {
      LoggerService.sync('查课进度通知未显示: $e');
      return false;
    }
  }

  Future<void> cancelAttendanceProgress() async {
    if (!_android) return;
    try {
      await init();
      await _channel.invokeMethod<void>('cancelProgress');
    } catch (e) {
      LoggerService.sync('取消查课通知失败: $e');
    }
  }
}
