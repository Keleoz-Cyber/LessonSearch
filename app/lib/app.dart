import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/logger/logger_service.dart';
import 'core/notification/notification_service.dart';
import 'core/router/app_router.dart';
import 'features/attendance/domain/models.dart';
import 'shared/design_system/theme.dart';
import 'shared/providers.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class App extends ConsumerStatefulWidget {
  const App({super.key});
  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  NotificationService? _notifications;
  bool _startupSyncing = false;
  bool _openingNotification = false;
  int _progressGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifications = ref.read(notificationServiceProvider);
      _notifications!.openPayload.addListener(_onNotification);
      appRouter.routerDelegate.addListener(_onNotification);
      ref.listenManual(isLoggedInProvider, (previous, loggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!loggedIn) {
            _progressGeneration++;
            unawaited(_notifications!.cancelAttendanceProgress());
            if (previous == true && ref.read(authExpiredProvider)) {
              appRouter.go('/login');
              _message('登录已过期，本地数据已保留，请重新登录');
            } else if (previous == true) {
              appRouter.go('/');
            }
          } else {
            unawaited(_checkPendingSyncOnStartup());
            unawaited(_reconcileNotifications());
            _onNotification();
          }
        });
      });
      ref.listenManual(rollCallProvider, (previous, next) {
        unawaited(
          _refreshProgress(
            requestPermission:
                previous?.task?.id != next.task?.id && next.task != null,
          ),
        );
      });
      ref.listenManual(nameCheckProvider, (previous, next) {
        unawaited(
          _refreshProgress(
            requestPermission:
                previous?.task?.id != next.task?.id && next.task != null,
          ),
        );
      });
      unawaited(_checkPendingSyncOnStartup());
      unawaited(_reconcileNotifications());
      _onNotification();
    });
  }

  @override
  void dispose() {
    _progressGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    appRouter.routerDelegate.removeListener(_onNotification);
    _notifications?.openPayload.removeListener(_onNotification);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_reconcileNotifications());
      _onNotification();
    }
  }

  void _message(String text, {bool showIssues = false}) {
    if (!mounted) return;
    final messenger = appScaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 3),
        action: showIssues
            ? SnackBarAction(
                label: '查看',
                onPressed: () => appRouter.push('/settings/sync-issues'),
              )
            : null,
      ),
    );
  }

  Future<void> _checkPendingSyncOnStartup() async {
    if (!mounted ||
        _startupSyncing ||
        !ref.read(authServiceProvider).isLoggedIn) {
      return;
    }
    _startupSyncing = true;
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final service = ref.read(syncServiceProvider);
      if (await local.getSyncIssueCount() == 0) return;
      final result = await service.syncNow();
      final remaining = await local.getSyncIssueCount();
      if (!mounted) return;
      if (remaining > 0 || result.failed > 0) {
        _message('仍有 $remaining 项未同步，请查看详情', showIssues: true);
      } else {
        _message('同步完成');
      }
    } catch (e) {
      LoggerService.sync('启动同步检查失败: $e', isError: true);
    } finally {
      _startupSyncing = false;
    }
  }

  Future<void> _reconcileNotifications() async {
    if (!mounted || !ref.read(authServiceProvider).isLoggedIn) return;
    final service =
        _notifications ??
        ref.read<NotificationService>(notificationServiceProvider);
    final repo = ref.read(dutyPlanRepositoryProvider);
    try {
      await service.reconcile(repo);
      if (!mounted) return;
      ref.invalidate(dutyPlansProvider);
      ref.invalidate(upcomingDutyPlansProvider);
      await _refreshProgress();
    } catch (e) {
      LoggerService.sync('提醒核对失败: $e', isError: true);
    }
  }

  bool _active(AttendanceTask? task) =>
      task != null &&
      task.status != TaskStatus.abandoned &&
      task.phase != TaskPhase.finished &&
      task.phase != TaskPhase.selecting;

  Future<void> _refreshProgress({bool requestPermission = false}) async {
    if (!mounted) return;
    final generation = ++_progressGeneration;
    final notifications =
        _notifications ??
        ref.read<NotificationService>(notificationServiceProvider);
    final auth = ref.read(authServiceProvider);
    final expectedUserId = auth.userId;
    if (!auth.isLoggedIn) {
      await notifications.cancelAttendanceProgress();
      return;
    }
    try {
      final roll = ref.read(rollCallProvider);
      final name = ref.read(nameCheckProvider);
      AttendanceTask? task;
      var processed = 0;
      var total = 0;
      if (_active(roll.task) && roll.task!.userId == expectedUserId) {
        task = roll.task;
        processed = roll.calledRecordIds.length;
        total = roll.totalCount;
      }
      if (_active(name.task) &&
          name.task!.userId == expectedUserId &&
          (task == null || !name.task!.updatedAt.isBefore(task.updatedAt))) {
        task = name.task;
        processed = name.processedStudents;
        total = name.totalStudents;
      }
      if (task == null) {
        final repo = ref.read(attendanceRepositoryProvider);
        final students = ref.read(studentRepositoryProvider);
        final tasks = (await repo.getResumableTasks())
            .where((t) => t.userId == expectedUserId)
            .toList();
        if (tasks.isNotEmpty) {
          task = tasks.first;
          final records = await repo.getRecordsByTask(task.id);
          processed = records
              .where((r) => r.status != AttendanceStatus.pending)
              .length;
          final roster = await students.getStudentsByClasses(task.classIds);
          total = roster.values.fold<int>(0, (n, list) => n + list.length);
        }
      }
      if (!mounted ||
          generation != _progressGeneration ||
          ref.read(authServiceProvider).userId != expectedUserId) {
        return;
      }
      if (task == null) {
        await notifications.cancelAttendanceProgress();
        return;
      }
      if (requestPermission && !await notifications.isPermissionGranted()) {
        await notifications.requestPermission();
      }
      if (!mounted ||
          generation != _progressGeneration ||
          !ref.read(authServiceProvider).isLoggedIn ||
          ref.read(authServiceProvider).userId != expectedUserId) {
        return;
      }
      await notifications.showAttendanceProgress(
        taskId: task.id,
        title: task.type == TaskType.rollCall
            ? '点名进行中'
            : task.phase == TaskPhase.confirming
            ? '记名待确认'
            : task.phase == TaskPhase.textGenerating
            ? '汇报待完成'
            : '记名进行中',
        processed: processed,
        total: total,
      );
    } catch (e) {
      LoggerService.sync('查课进度通知更新失败: $e');
    }
  }

  void _onNotification() {
    if (mounted && _notifications?.openPayload.value != null) {
      unawaited(_openNotification());
    }
  }

  Future<void> _openNotification() async {
    if (!mounted || _openingNotification) return;
    final service = _notifications;
    final payload = service?.openPayload.value;
    if (payload == null) return;
    final auth = ref.read(authServiceProvider);
    final expectedUserId = auth.userId;
    if (!auth.isLoggedIn) {
      if (appRouter.routerDelegate.currentConfiguration.uri.path != '/login') {
        appRouter.go('/login');
      }
      return;
    }
    if (!auth.hasRealName) {
      if (appRouter.routerDelegate.currentConfiguration.uri.path !=
          '/real-name') {
        appRouter.go('/real-name');
      }
      return;
    }
    _openingNotification = true;
    service!.openPayload.value = null;
    try {
      if (!payload.startsWith('task:')) {
        appRouter.go('/duty-plan');
        return;
      }
      final task = await ref
          .read(attendanceRepositoryProvider)
          .getTask(payload.substring(5));
      if (!mounted || ref.read(authServiceProvider).userId != expectedUserId) {
        return;
      }
      if (task == null || task.userId != expectedUserId) {
        _message('任务不存在或不属于当前账号');
        return;
      }
      if (!_active(task)) {
        appRouter.go('/records/${task.id}');
        return;
      }
      if (task.type == TaskType.nameCheck) {
        await ref.read(nameCheckProvider.notifier).resumeTask(task.id);
        if (!mounted) return;
        final restored = ref.read(nameCheckProvider);
        if (ref.read(authServiceProvider).userId != expectedUserId ||
            restored.task?.id != task.id ||
            restored.error != null) {
          _message('任务恢复失败，请在首页重试');
          return;
        }
        if (task.phase == TaskPhase.confirming) {
          appRouter.go('/confirmation');
          return;
        }
        if (task.phase == TaskPhase.textGenerating) {
          appRouter.go('/text-gen', extra: {'taskId': task.id});
          return;
        }
      }
      final names = await ref
          .read(studentRepositoryProvider)
          .getClassNames(task.classIds);
      if (!mounted ||
          !ref.read(authServiceProvider).isLoggedIn ||
          ref.read(authServiceProvider).userId != expectedUserId) {
        return;
      }
      appRouter.go(
        task.type == TaskType.rollCall
            ? '/roll-call/execute'
            : '/name-check/execute',
        extra: {
          'classIds': task.classIds,
          'classNames': names,
          'gradeId': task.selectedGradeId ?? 0,
          'majorId': task.selectedMajorId ?? 0,
          'resumeTaskId': task.id,
        },
      );
    } catch (e) {
      if (mounted) _message('暂时无法打开任务，请在首页继续');
    } finally {
      _openingNotification = false;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: '查课',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: appScaffoldMessengerKey,
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: appRouter,
  );
}
