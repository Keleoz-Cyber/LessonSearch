import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lesson_search/core/notification/notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lesson_search/notifications');

  testWidgets(
    'Android system alarm delivers and progress notification is updated',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('系统通知验证'))),
        ),
      );
      final service = NotificationService();
      await service.init();
      await service.cancelAll();
      final permissions = await service.permissionState();
      expect(
        permissions.notificationsEnabled,
        isTrue,
        reason: 'Grant POST_NOTIFICATIONS to the test app before running.',
      );
      expect(
        permissions.exactAlarms,
        isTrue,
        reason: 'Allow exact alarms for deterministic delivery timing.',
      );
      final result = await service.scheduleDutyReminder(
        notificationId: 900011,
        title: '查课提醒测试',
        body: '这是一条本地验证通知',
        payload: 'plan:integration-test',
        scheduledAt: DateTime.now().add(const Duration(seconds: 4)),
      );
      expect(result.status, 'scheduledExact');
      await channel.invokeMethod<void>('restoreReminders');
      expect(
        (await service.pendingRequests()).where((r) => r.id == 900011),
        hasLength(1),
      );
      expect(
        await service.showAttendanceProgress(
          taskId: 'integration-test',
          title: '查课进度测试',
          processed: 2,
          total: 30,
        ),
        isTrue,
      );
      expect(
        await channel.invokeListMethod<int>('activeNotificationIds'),
        contains(2147483000),
      );
      await service.showAttendanceProgress(
        taskId: 'integration-test',
        title: '查课进度测试',
        processed: 3,
        total: 30,
      );
      await Future<void>.delayed(const Duration(seconds: 7));
      expect(
        (await service.pendingRequests()).where((r) => r.id == 900011),
        isEmpty,
      );
      expect(
        await channel.invokeListMethod<int>('activeNotificationIds'),
        contains(900011),
      );
      await service.cancel(900011);
      await service.cancelAttendanceProgress();
      expect(
        await channel.invokeListMethod<int>('activeNotificationIds'),
        isNot(contains(900011)),
      );
      expect(
        await channel.invokeListMethod<int>('activeNotificationIds'),
        isNot(contains(2147483000)),
      );
    },
  );

  testWidgets(
    'optional fixture for host-side process death and boot restore verification',
    (tester) async {
      if (!const bool.fromEnvironment('KEEP_SYSTEM_NOTIFICATION_FIXTURE')) {
        return;
      }
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('后台提醒验证已安排'))),
      );
      final service = NotificationService();
      await service.init();
      final result = await service.scheduleDutyReminder(
        notificationId: 900012,
        title: '后台查课提醒测试',
        body: '进程退出后由系统发送',
        payload: 'plan:process-death-test',
        scheduledAt: DateTime.now().add(const Duration(minutes: 2)),
      );
      expect(result.isScheduled, isTrue);
      expect(
        (await service.pendingRequests()).map((r) => r.id),
        contains(900012),
      );
    },
  );
}
