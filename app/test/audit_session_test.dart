import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lesson_search/app.dart';
import 'package:lesson_search/core/auth/account_session.dart';
import 'package:lesson_search/core/database/app_database.dart' as db;
import 'package:lesson_search/core/notification/notification_service.dart';
import 'package:lesson_search/core/router/app_router.dart';
import 'package:lesson_search/core/sync/sync_service.dart';
import 'package:lesson_search/features/attendance/data/attendance_repository.dart';
import 'package:lesson_search/features/attendance/data/local/attendance_local_ds.dart';
import 'package:lesson_search/features/attendance/data/remote/attendance_remote_ds.dart';
import 'package:lesson_search/features/attendance/domain/models.dart';
import 'package:lesson_search/features/auth/data/auth_service.dart';
import 'package:lesson_search/features/duty_plan/data/duty_plan_repository.dart';
import 'package:lesson_search/features/student/data/student_repository.dart';
import 'package:lesson_search/shared/providers.dart';

class SessionNotifications implements NotificationService {
  int cancellations = 0;
  int progressCancellations = 0;
  int reconciliations = 0;
  final progressTasks = <String>[];
  Completer<void>? cancelGate;
  @override
  final ValueNotifier<String?> openPayload = ValueNotifier(null);
  @override
  Future<void> cancelAll() async {
    cancellations++;
    await cancelGate?.future;
    openPayload.value = null;
  }

  @override
  Future<void> reconcile(DutyPlanRepository repo) async {
    reconciliations++;
  }

  @override
  Future<void> cancelAttendanceProgress() async {
    progressCancellations++;
  }

  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<bool> showAttendanceProgress({
    required String taskId,
    required String title,
    required int processed,
    required int total,
    bool requestPermissionIfNeeded = false,
  }) async {
    progressTasks.add(taskId);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class SessionSync implements SyncService {
  int pauses = 0;
  int starts = 0;
  int syncs = 0;
  Completer<void>? pauseGate;
  @override
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  @override
  final ValueNotifier<({int current, int total})?> progress = ValueNotifier(
    null,
  );
  @override
  Stream<SyncCompleteEvent> get onSyncComplete => const Stream.empty();
  @override
  Future<void> pauseAndDrain() async {
    pauses++;
    await pauseGate?.future;
  }

  @override
  void start() {
    starts++;
  }

  @override
  Future<SyncResult> syncNow() async {
    syncs++;
    return (success: 0, failed: 0, skipped: 0);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class SessionRemote implements AttendanceRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class SessionStudents implements StudentRepository {
  @override
  Future<void> ensureStudentsBatch(List<int> ids) async {}
  @override
  Future<Map<int, ClassInfo>> getClassMap() async => {
    10: const ClassInfo(
      id: 10,
      gradeId: 1,
      majorId: 1,
      classCode: 'A',
      displayName: 'Test class',
    ),
  };
  @override
  Future<List<String>> getClassNames(List<int> ids) async => ['Test class'];
  @override
  Future<Map<int, List<StudentInfo>>> getStudentsByClasses(
    List<int> ids,
  ) async => {
    10: [
      const StudentInfo(
        id: 1,
        name: 'Restored student',
        studentNo: '001',
        classId: 10,
      ),
    ],
  };
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Map<String, dynamic> response(int id) => {
  'token': 'test-$id',
  'user': {
    'id': id,
    'email': '$id@example.test',
    'nickname': null,
    'real_name': 'Test User $id',
    'role': 'member',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;
  late SharedPreferences prefs;
  late AuthService auth;
  late SessionNotifications notifications;
  late SessionSync sync;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = AuthService(prefs);
    await auth.saveAuth(
      token: 'old-token',
      userId: 1,
      email: 'old@example.test',
      realName: 'Old User',
    );
    database = db.AppDatabase(executor: NativeDatabase.memory());
    notifications = SessionNotifications();
    sync = SessionSync();
  });
  tearDown(() async {
    await database.close();
  });

  Future<void> seed({bool dirty = false}) async {
    await database
        .into(database.attendanceTasks)
        .insert(
          db.AttendanceTasksCompanion.insert(
            id: 'old-task',
            type: 'name_check',
            userId: const Value(1),
            status: const Value('completed'),
            phase: const Value('finished'),
          ),
        );
    if (dirty) {
      await AttendanceLocalDataSource(database).enqueueSync(
        entityType: 'task',
        entityId: 'old-task',
        action: 'update',
        payload: {'status': 'completed'},
      );
    }
  }

  Future<WidgetRef> mountSession(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          syncServiceProvider.overrideWithValue(sync),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const Scaffold(body: Text('Session host'));
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets(
    'dirty account switch is blocked and retains original credentials/data',
    (tester) async {
      await seed(dirty: true);
      final ref = await mountSession(tester);
      await expectLater(
        finalizeAuthentication(ref, response(2)),
        throwsA(isA<AccountSessionException>()),
      );
      expect(auth.userId, 1);
      expect(auth.token, 'old-token');
      expect((await database.select(database.attendanceTasks).get()).length, 1);
      expect(notifications.cancellations, 0);
      expect(sync.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'same account reauthentication keeps pending data and reminders',
    (tester) async {
      await seed(dirty: true);
      final ref = await mountSession(tester);
      await finalizeAuthentication(ref, response(1));
      expect(auth.userId, 1);
      expect(auth.token, 'test-1');
      expect((await database.select(database.attendanceTasks).get()).length, 1);
      expect(await database.getUnsyncedCount(), 1);
      expect(notifications.cancellations, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'safe account switch drains, cancels reminders, clears cache then commits B',
    (tester) async {
      await seed();
      await prefs.setInt('data_version', 9);
      await prefs.setStringList('sync_class_student_ids_10', ['1']);
      sync.pauseGate = Completer<void>();
      final ref = await mountSession(tester);
      final switching = finalizeAuthentication(ref, response(2));
      await tester.pump();
      expect(auth.userId, 1);
      expect(notifications.cancellations, 0);
      sync.pauseGate!.complete();
      await switching;
      expect(auth.userId, 2);
      expect(auth.token, 'test-2');
      expect(notifications.cancellations, 1);
      expect(await database.select(database.attendanceTasks).get(), isEmpty);
      expect(prefs.getInt('data_version'), isNull);
      expect(prefs.getStringList('sync_class_student_ids_10'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'session completion after widget disposal uses captured container safely',
    (tester) async {
      await seed();
      sync.pauseGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          syncServiceProvider.overrideWithValue(sync),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      late WidgetRef ref;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, value, _) {
                ref = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final switching = finalizeAuthentication(ref, response(2));
      await tester.pumpWidget(const SizedBox.shrink());
      sync.pauseGate!.complete();
      await switching;
      expect(auth.userId, 2);
      expect(tester.takeException(), isNull);
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('safe logout clears credentials and reminders only after drain', (
    tester,
  ) async {
    await seed();
    final ref = await mountSession(tester);
    await logoutCurrentAccount(ref);
    expect(auth.token, isNull);
    expect(auth.userId, isNull);
    expect(notifications.cancellations, 1);
    expect(await database.select(database.attendanceTasks).get(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('login and logout serialize account cancellation and commit', (
    tester,
  ) async {
    await seed();
    notifications.cancelGate = Completer<void>();
    final ref = await mountSession(tester);
    final loggingIn = finalizeAuthentication(ref, response(2));
    await tester.pump(const Duration(milliseconds: 1));
    expect(notifications.cancellations, 1);
    final loggingOut = logoutCurrentAccount(ref);
    await tester.pump(const Duration(milliseconds: 1));
    final cancellationsWhileFirstBlocked = notifications.cancellations;
    notifications.cancelGate!.complete();
    await Future.wait([loggingIn, loggingOut]);
    expect(cancellationsWhileFirstBlocked, 1);
    expect(notifications.cancellations, 2);
    expect(auth.userId, isNull);
    expect(auth.token, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'App startup sync warning uses installed ScaffoldMessenger context',
    (tester) async {
      await seed(dirty: true);
      appRouter.go('/login');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            studentRepositoryProvider.overrideWithValue(SessionStudents()),
            syncServiceProvider.overrideWithValue(sync),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('仍有 1 项未同步'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/login');
    },
  );

  testWidgets(
    '401 auth transition navigates via global router without context errors',
    (tester) async {
      appRouter.go('/login');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            studentRepositoryProvider.overrideWithValue(SessionStudents()),
            syncServiceProvider.overrideWithValue(sync),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(App)),
        listen: false,
      );
      await auth.clearTokenOnly();
      container.read(authExpiredProvider.notifier).state = true;
      container.invalidate(authServiceProvider);
      container.invalidate(isLoggedInProvider);
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/login');
      expect(find.text('登录已过期，本地数据已保留，请重新登录'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/login');
    },
  );

  testWidgets(
    'logged-out notification stays pending without same-route navigation loop',
    (tester) async {
      await auth.clearAuth();
      notifications.openPayload.value = 'plan:test-plan';
      appRouter.go('/login');
      var navigations = 0;
      void counted() {
        navigations++;
      }

      appRouter.routerDelegate.addListener(counted);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            studentRepositoryProvider.overrideWithValue(SessionStudents()),
            syncServiceProvider.overrideWithValue(sync),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const App(),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(navigations, lessThan(4));
      expect(notifications.openPayload.value, 'plan:test-plan');
      expect(appRouter.routeInformationProvider.value.uri.path, '/login');
      expect(tester.takeException(), isNull);
      appRouter.routerDelegate.removeListener(counted);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/login');
    },
  );

  testWidgets(
    'notification task tap hydrates completed confirmation before navigation',
    (tester) async {
      final local = AttendanceLocalDataSource(database, userId: 1);
      final repository = AttendanceRepository(local, SessionRemote());
      final task = await repository.createTask(
        type: TaskType.nameCheck,
        classIds: [10],
        userId: 1,
      );
      await repository.createRecord(
        taskId: task.id,
        studentId: 1,
        classId: 10,
        status: AttendanceStatus.absent,
      );
      await repository.updateTaskStatus(
        task,
        status: TaskStatus.completed,
        phase: TaskPhase.confirming,
      );
      await local.clearSyncQueue();
      notifications.openPayload.value = 'task:${task.id}';
      appRouter.go('/login');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            attendanceRepositoryProvider.overrideWithValue(repository),
            studentRepositoryProvider.overrideWithValue(SessionStudents()),
            syncServiceProvider.overrideWithValue(sync),
            notificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/confirmation',
      );
      expect(find.text('Restored student'), findsOneWidget);
      expect(find.text('无任务数据'), findsNothing);
      expect(notifications.openPayload.value, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/login');
    },
  );
}
