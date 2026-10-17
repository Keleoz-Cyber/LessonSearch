import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The real plugin singleton must be switched between Android and iOS in tests.
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Build a real pre-upgrade SQLite fixture, retained between two Drift opens.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:lesson_search/core/database/app_database.dart';
import 'package:lesson_search/core/notification/notification_service.dart';
import 'package:lesson_search/features/duty_plan/data/duty_plan_repository.dart';
import 'package:lesson_search/features/duty_plan/domain/duty_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('lesson_search/notifications');
  const pluginChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AppDatabase db;
  late bool fixtureDbClosed;
  late DutyPlanRepository repo;
  late List<MethodCall> nativeCalls;
  late List<MethodCall> pluginCalls;
  late List<Map<String, Object?>> pending;
  late bool notificationsEnabled;
  late bool exactAlarms;
  late bool requestAllowed;
  late bool throwSchedule;
  late String scheduleStatus;
  String? launchPayload;

  NotificationService service(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final plugin = FlutterLocalNotificationsPlugin();
    FlutterLocalNotificationsPlatform.instance = platform == TargetPlatform.iOS
        ? IOSFlutterLocalNotificationsPlugin()
        : AndroidFlutterLocalNotificationsPlugin();
    return NotificationService.forTesting(plugin: plugin, platform: platform);
  }

  DutyPlan plan(
    String id, {
    int? notificationId,
    bool enabled = true,
    bool elapsed = false,
  }) {
    final now = DateTime.now();
    return DutyPlan(
      id: id,
      weekNumber: 6,
      weekday: 2,
      period: 1,
      classIds: const ['1'],
      className: '测试班',
      classroom: 'A101',
      notificationId: notificationId ?? DutyPlan.notificationIdFor(id),
      reminderEnabled: enabled,
      classStartAt: elapsed
          ? now.subtract(const Duration(hours: 1))
          : now.add(const Duration(days: 2)),
      createdAt: now,
    );
  }

  Future<void> incoming(
    MethodChannel channel,
    String method,
    Object? arguments,
  ) async {
    final done = Completer<void>();
    // This is an inbound native-to-Dart message, not an outgoing mock call.
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({'native_reminders_migrated': true});
    nativeCalls = [];
    pluginCalls = [];
    pending = [];
    notificationsEnabled = true;
    exactAlarms = true;
    requestAllowed = true;
    throwSchedule = false;
    scheduleStatus = 'scheduledExact';
    launchPayload = null;
    db = AppDatabase(executor: NativeDatabase.memory());
    fixtureDbClosed = false;
    repo = DutyPlanRepository(db);
    messenger.setMockMethodCallHandler(
      timezone,
      (call) async => 'Asia/Shanghai',
    );
    messenger.setMockMethodCallHandler(native, (call) async {
      nativeCalls.add(call);
      final args = call.arguments;
      switch (call.method) {
        case 'consumeLaunchPayload':
          return launchPayload;
        case 'permissionState':
          return {
            'notificationsEnabled': notificationsEnabled,
            'exactAlarms': exactAlarms,
            'liveUpdatesSupported': true,
            'liveUpdatesEnabled': false,
          };
        case 'scheduleReminder':
          if (throwSchedule) {
            throw PlatformException(
              code: 'schedule_error',
              message: 'synthetic native failure',
            );
          }
          return {
            'status': scheduleStatus,
            if (scheduleStatus == 'failed') 'error': 'native rejected alarm',
          };
        case 'pendingReminders':
          return pending;
        case 'cancelReminder':
          pending.removeWhere((item) => item['id'] == (args as Map)['id']);
          return null;
        case 'cancelAll':
          pending.clear();
          return null;
        case 'showProgress':
          return notificationsEnabled;
        case 'cancelProgress':
        case 'openSettings':
        case 'restoreReminders':
          return null;
      }
      throw MissingPluginException('Unexpected native method ${call.method}');
    });
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      pluginCalls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {
            'notificationLaunchedApp': launchPayload != null,
            if (launchPayload != null)
              'notificationResponse': {
                'notificationId': 7,
                'notificationResponseType': 0,
                'payload': launchPayload,
              },
          };
        case 'checkPermissions':
          return {
            'isEnabled': notificationsEnabled,
            'isAlertEnabled': notificationsEnabled,
            'isBadgeEnabled': notificationsEnabled,
            'isSoundEnabled': notificationsEnabled,
            'isProvisionalEnabled': false,
            'isCriticalEnabled': false,
          };
        case 'requestPermissions':
        case 'requestNotificationsPermission':
          notificationsEnabled = requestAllowed;
          return requestAllowed;
        case 'requestExactAlarmsPermission':
          return exactAlarms;
        case 'zonedSchedule':
          if (throwSchedule) {
            throw PlatformException(
              code: 'schedule_error',
              message: 'synthetic iOS failure',
            );
          }
          return null;
        case 'pendingNotificationRequests':
          return pending;
        case 'cancel':
          pending.removeWhere((item) => item['id'] == call.arguments);
          return null;
        case 'cancelAll':
          pending.clear();
          return null;
      }
      throw MissingPluginException('Unexpected plugin method ${call.method}');
    });
  });

  tearDown(() async {
    if (!fixtureDbClosed) await db.close();
    native.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(timezone, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Android exact, inexact, denied and failed native results stay distinct',
    () async {
      final notifications = service(TargetPlatform.android);
      for (final status in [
        'scheduledExact',
        'scheduledInexact',
        'permissionDenied',
        'failed',
      ]) {
        scheduleStatus = status;
        final result = await notifications.scheduleDutyReminder(
          notificationId: 101,
          title: '提醒',
          body: '查课',
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          payload: 'plan:a',
        );
        expect(result.status, status);
        expect(result.isScheduled, status.startsWith('scheduled'));
      }
      final call = nativeCalls.lastWhere(
        (call) => call.method == 'scheduleReminder',
      );
      expect((call.arguments as Map)['payload'], 'plan:a');
      expect((call.arguments as Map)['scheduledAt'], isA<int>());
    },
  );

  test('Android actual permission flags are returned, not guessed', () async {
    notificationsEnabled = false;
    exactAlarms = false;
    final state = await service(TargetPlatform.android).permissionState();
    expect(state.supported, isTrue);
    expect(state.notificationsEnabled, isFalse);
    expect(state.exactAlarms, isFalse);
    expect(state.liveUpdatesSupported, isTrue);
    expect(state.liveUpdatesEnabled, isFalse);
  });

  test(
    'Android native exception becomes failed and a later retry can succeed',
    () async {
      final notifications = service(TargetPlatform.android);
      final saved = await repo.upsert(plan('retry'));
      throwSchedule = true;
      final failed = await notifications.syncPlan(repo, saved.id);
      expect(failed.status, 'failed');
      expect(
        (await repo.getById(saved.id))!.reminderError,
        contains('synthetic native failure'),
      );
      throwSchedule = false;
      expect(
        (await notifications.syncPlan(repo, saved.id)).isScheduled,
        isTrue,
      );
      expect((await repo.getById(saved.id))!.reminderError, isNull);
    },
  );

  test(
    'elapsed reminder cancels stale request without scheduling again',
    () async {
      final notifications = service(TargetPlatform.android);
      final saved = await repo.upsert(plan('elapsed', elapsed: true));
      final result = await notifications.syncPlan(repo, saved.id);
      expect(result.status, 'elapsed');
      expect(
        nativeCalls.where((call) => call.method == 'scheduleReminder'),
        isEmpty,
      );
      expect(
        nativeCalls
            .where((call) => call.method == 'cancelReminder')
            .single
            .arguments,
        {'id': saved.notificationId},
      );
      expect((await repo.getById(saved.id))!.reminderStatus, 'elapsed');
    },
  );

  test('Android migration cancels plugin alarms only once', () async {
    SharedPreferences.setMockInitialValues({});
    await service(TargetPlatform.android).init();
    await service(TargetPlatform.android).init();
    expect(pluginCalls.where((call) => call.method == 'cancelAll').length, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'native_reminders_migrated',
      ),
      isTrue,
    );
  });

  test(
    'Android initialization restores native requests once despite concurrent callers',
    () async {
      final notifications = service(TargetPlatform.android);
      await Future.wait([notifications.init(), notifications.init()]);
      await notifications.init();
      expect(
        nativeCalls.where((call) => call.method == 'restoreReminders').length,
        1,
      );
      expect(
        pluginCalls.where((call) => call.method == 'initialize').length,
        1,
      );
    },
  );

  test('Android cold and warm payloads both reach the notifier', () async {
    launchPayload = 'plan:cold';
    final notifications = service(TargetPlatform.android);
    await notifications.init();
    expect(notifications.openPayload.value, 'plan:cold');
    await incoming(native, 'openPayload', 'task:warm');
    expect(notifications.openPayload.value, 'task:warm');
    await notifications.cancelAll();
    expect(notifications.openPayload.value, isNull);
  });

  test(
    'iOS queries real plugin permissions and requests after first denial',
    () async {
      notificationsEnabled = false;
      final notifications = service(TargetPlatform.iOS);
      expect(await notifications.isPermissionGranted(), isFalse);
      expect(
        pluginCalls.any((call) => call.method == 'checkPermissions'),
        isTrue,
      );
      final initArgs =
          pluginCalls
                  .firstWhere((call) => call.method == 'initialize')
                  .arguments
              as Map;
      expect(initArgs['requestAlertPermission'], isFalse);
      final saved = await repo.upsert(plan('ios-first'));
      final result = await notifications.syncPlan(
        repo,
        saved.id,
        requestPermissionIfNeeded: true,
      );
      expect(result.isScheduled, isTrue);
      final request =
          pluginCalls
                  .singleWhere((call) => call.method == 'requestPermissions')
                  .arguments
              as Map;
      expect(request['alert'], isTrue);
      expect(request['badge'], isTrue);
      expect(request['sound'], isTrue);
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule').length,
        1,
      );
      expect(nativeCalls, isEmpty);
    },
  );

  test('iOS denied authorization persists denial without scheduling', () async {
    notificationsEnabled = false;
    requestAllowed = false;
    final notifications = service(TargetPlatform.iOS);
    final saved = await repo.upsert(plan('ios-denied'));
    expect(
      (await notifications.syncPlan(
        repo,
        saved.id,
        requestPermissionIfNeeded: true,
      )).status,
      'permissionDenied',
    );
    final stored = (await repo.getById(saved.id))!;
    expect(
      stored.reminderEnabled,
      isTrue,
      reason: 'Keep user intent separate from OS delivery status',
    );
    expect(stored.reminderStatus, 'permissionDenied');
    expect(
      pluginCalls.where((call) => call.method == 'zonedSchedule'),
      isEmpty,
    );
  });

  test(
    'iOS scheduling failure is not misreported as elapsed or scheduled',
    () async {
      final notifications = service(TargetPlatform.iOS);
      throwSchedule = true;
      final saved = await repo.upsert(plan('ios-error'));
      expect((await notifications.syncPlan(repo, saved.id)).status, 'failed');
      expect(
        (await repo.getById(saved.id))!.reminderError,
        contains('synthetic iOS failure'),
      );
    },
  );

  test(
    'iOS cold launch and real plugin warm callback carry payloads',
    () async {
      launchPayload = 'plan:ios-cold';
      final notifications = service(TargetPlatform.iOS);
      await notifications.init();
      expect(notifications.openPayload.value, 'plan:ios-cold');
      await incoming(pluginChannel, 'didReceiveNotificationResponse', {
        'notificationId': 7,
        'notificationResponseType': 0,
        'payload': 'plan:ios-warm',
      });
      expect(notifications.openPayload.value, 'plan:ios-warm');
    },
  );

  test(
    'repository resolves collisions and repaired IDs remain unique and stable',
    () async {
      final a = await repo.upsert(plan('same-slot-a', notificationId: 611));
      final b = await repo.upsert(plan('same-slot-b', notificationId: 611));
      expect(a.notificationId, isNot(b.notificationId));
      expect(a.weekNumber, b.weekNumber);
      expect(a.period, b.period);
      final repaired = await repo.repairNotificationIds();
      expect(repaired.map((p) => p.notificationId).toSet().length, 2);
      final ids = {for (final p in repaired) p.id: p.notificationId};
      final again = await repo.repairNotificationIds();
      expect({for (final p in again) p.id: p.notificationId}, ids);
      for (final value in again) {
        expect((await repo.upsert(value)).notificationId, ids[value.id]);
      }
    },
  );

  test(
    'reconcile cancels orphaned, disabled and elapsed alarms; persists results',
    () async {
      final notifications = service(TargetPlatform.android);
      final upcoming = await repo.upsert(plan('wanted'));
      final disabled = await repo.upsert(plan('disabled', enabled: false));
      final elapsed = await repo.upsert(plan('past', elapsed: true));
      pending.addAll([
        {'id': upcoming.notificationId, 'title': 'keep'},
        {'id': disabled.notificationId, 'title': 'disabled'},
        {'id': elapsed.notificationId, 'title': 'past'},
        {'id': 999, 'title': 'orphan'},
      ]);
      scheduleStatus = 'scheduledInexact';
      await notifications.reconcile(repo);
      final cancelled = nativeCalls
          .where((call) => call.method == 'cancelReminder')
          .map((call) => (call.arguments as Map)['id'])
          .toSet();
      expect(
        cancelled,
        containsAll([999, disabled.notificationId, elapsed.notificationId]),
      );
      expect(cancelled, isNot(contains(upcoming.notificationId)));
      expect(
        (await repo.getById(upcoming.id))!.reminderStatus,
        'scheduledInexact',
      );
      expect((await repo.getById(disabled.id))!.reminderStatus, 'disabled');
      expect((await repo.getById(elapsed.id))!.reminderStatus, 'elapsed');
    },
  );

  test(
    'disable and delete cancel only that plan and keep another same-slot plan',
    () async {
      final notifications = service(TargetPlatform.android);
      final first = await repo.upsert(plan('first'));
      final second = await repo.upsert(plan('second'));
      await notifications.setPlanEnabled(repo, first.id, false);
      expect((await repo.getById(first.id))!.reminderEnabled, isFalse);
      expect((await repo.getById(first.id))!.reminderStatus, 'disabled');
      await notifications.deletePlan(repo, first.id);
      expect(await repo.getById(first.id), isNull);
      expect(await repo.getById(second.id), isNotNull);
      final cancelled = nativeCalls
          .where((call) => call.method == 'cancelReminder')
          .map((call) => (call.arguments as Map)['id'])
          .toSet();
      expect(cancelled, {first.notificationId});
    },
  );

  test(
    'iOS reconciliation schedules at most 60 future reminders and marks overflow',
    () async {
      final notifications = service(TargetPlatform.iOS);
      for (var index = 0; index < 61; index++) {
        final saved = await repo.upsert(plan('capacity-$index'));
        pending.add({
          'id': saved.notificationId,
          'title': 'previously scheduled',
        });
      }
      await notifications.reconcile(repo);
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule').length,
        60,
      );
      final plans = await repo.getAll();
      expect(
        plans.where((p) => p.reminderStatus == 'scheduledExact').length,
        60,
      );
      expect(plans.where((p) => p.reminderStatus == 'failed').length, 1);
      final overflow = plans.singleWhere((p) => p.reminderStatus == 'failed');
      expect(pending.length, 60);
      expect(
        pending.any((request) => request['id'] == overflow.notificationId),
        isFalse,
      );
      expect(
        plans.singleWhere((p) => p.reminderStatus == 'failed').reminderError,
        contains('上限'),
      );
    },
  );

  test(
    'iOS direct 61st request is rejected but replacing an existing request is allowed',
    () async {
      final notifications = service(TargetPlatform.iOS);
      pending.addAll([
        for (var id = 1; id <= 60; id++)
          {'id': id, 'title': 'Existing reminder $id'},
      ]);
      final scheduledAt = DateTime.now().add(const Duration(days: 1));
      final overflow = await notifications.scheduleDutyReminder(
        notificationId: 61,
        title: 'Would exceed capacity',
        body: 'Keep pending requests intact',
        scheduledAt: scheduledAt,
      );
      expect(overflow.status, 'failed');
      expect(overflow.error, contains('上限'));
      expect(
        pluginCalls.where((call) => call.method == 'zonedSchedule'),
        isEmpty,
      );
      expect(pending.length, 60);

      final replacement = await notifications.scheduleDutyReminder(
        notificationId: 1,
        title: 'Replacement',
        body: 'Uses an existing slot',
        scheduledAt: scheduledAt,
      );
      expect(replacement.isScheduled, isTrue);
      final scheduled = pluginCalls.singleWhere(
        (call) => call.method == 'zonedSchedule',
      );
      expect((scheduled.arguments as Map)['id'], 1);
      expect(pending.length, 60);
    },
  );

  test(
    'SQLite v4 to v5 preserves plans, initializes reminder status and recovers interrupted sync only',
    () async {
      await db.close();
      fixtureDbClosed = true;
      final raw = sqlite.sqlite3.openInMemory();
      final bootstrap = AppDatabase(
        executor: NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      // Versions 4 and 5 differ only by these two columns. Build the complete
      // old schema from real generated Drift DDL, not a partial table mock.
      await bootstrap.customSelect('SELECT COUNT(*) FROM duty_plan_rows').get();
      await bootstrap.customStatement(
        'ALTER TABLE duty_plan_rows DROP COLUMN reminder_status',
      );
      await bootstrap.customStatement(
        'ALTER TABLE duty_plan_rows DROP COLUMN reminder_error',
      );
      await bootstrap.customStatement('PRAGMA user_version = 4');
      final start = DateTime(2026, 10, 20, 8, 30);
      final created = DateTime(2026, 10, 17, 12);
      await bootstrap.customStatement(
        '''
        INSERT INTO duty_plan_rows
          (id, week_number, weekday, period, class_ids, class_name, classroom,
           remark, notification_id, reminder_enabled, class_start_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          'legacy-plan',
          6,
          2,
          1,
          '["10","11"]',
          '原有计划',
          'A101',
          '保留这条备注',
          621,
          1,
          start.millisecondsSinceEpoch ~/ 1000,
          created.millisecondsSinceEpoch ~/ 1000,
        ],
      );
      for (final entry in const [
        [1, 'syncing', 2],
        [2, 'failed', 5],
        [3, 'synced', 0],
        [4, 'pending', 1],
      ]) {
        await bootstrap.customStatement(
          '''
          INSERT INTO sync_queue
            (id, entity_type, entity_id, action, payload, sync_status, retry_count)
          VALUES (?, 'record', ?, 'update', ?, ?, ?)
        ''',
          [
            entry[0],
            'record-${entry[0]}',
            '{"status":"absent"}',
            entry[1],
            entry[2],
          ],
        );
      }
      await bootstrap.close();

      final upgraded = AppDatabase(executor: NativeDatabase.opened(raw));
      try {
        final plans = await DutyPlanRepository(upgraded).getAll();
        expect(plans.length, 1);
        final old = plans.single;
        expect(old.id, 'legacy-plan');
        expect(old.weekNumber, 6);
        expect(old.weekday, 2);
        expect(old.period, 1);
        expect(old.classIds, ['10', '11']);
        expect(old.className, '原有计划');
        expect(old.classroom, 'A101');
        expect(old.remark, '保留这条备注');
        expect(old.notificationId, 621);
        expect(old.reminderEnabled, isTrue);
        expect(old.reminderStatus, 'unknown');
        expect(old.reminderError, isNull);
        expect(old.classStartAt, start);
        expect(old.createdAt, created);
        final rows = await (upgraded.select(
          upgraded.syncQueue,
        )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
        expect(rows.map((row) => row.id).toList(), [1, 2, 3, 4]);
        expect(rows.map((row) => row.syncStatus).toList(), [
          'pending',
          'failed',
          'synced',
          'pending',
        ]);
        expect(rows.map((row) => row.retryCount).toList(), [2, 5, 0, 1]);
        expect(
          rows.every((row) => row.payload == '{"status":"absent"}'),
          isTrue,
        );
        final version = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 5);
      } finally {
        await upgraded.close();
      }
    },
  );

  test(
    'unsupported platform is explicit and never invokes native scheduling',
    () async {
      final notifications = service(TargetPlatform.windows);
      expect((await notifications.permissionState()).supported, isFalse);
      final result = await notifications.scheduleDutyReminder(
        notificationId: 10,
        title: 'x',
        body: 'y',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(result.status, 'unsupported');
      expect(nativeCalls, isEmpty);
    },
  );
}
