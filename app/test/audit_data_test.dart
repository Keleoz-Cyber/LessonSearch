import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lesson_search/core/database/app_database.dart' as db;
import 'package:lesson_search/core/network/api_client.dart';
import 'package:lesson_search/core/sync/sync_service.dart';
import 'package:lesson_search/features/attendance/application/name_check_notifier.dart';
import 'package:lesson_search/features/attendance/application/roll_call_notifier.dart';
import 'package:lesson_search/features/attendance/data/attendance_repository.dart';
import 'package:lesson_search/features/attendance/data/local/attendance_local_ds.dart';
import 'package:lesson_search/features/attendance/data/remote/attendance_remote_ds.dart';
import 'package:lesson_search/features/attendance/domain/models.dart';
import 'package:lesson_search/features/auth/data/auth_service.dart';
import 'package:lesson_search/features/records/data/records_repository.dart';
import 'package:lesson_search/features/student/data/student_repository.dart';
import 'package:lesson_search/shared/providers.dart';

class FakeRemote implements AttendanceRemoteDataSource {
  final statuses = <AttendanceStatus>[];
  final createdOwners = <int?>[];
  final deleted = <int>[];
  final started = Completer<void>();
  Completer<void>? gate;
  Object? error;
  @override
  Future<Map<String, dynamic>> updateRecordByTaskStudent(
    String taskId,
    int studentId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    statuses.add(status);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (error != null) throw error!;
    return {};
  }

  @override
  Future<Map<String, dynamic>> createTask(AttendanceTask task) async {
    createdOwners.add(task.userId);
    return {};
  }

  @override
  Future<Map<String, dynamic>> updateTask(
    String taskId, {
    TaskStatus? status,
    TaskPhase? phase,
    int? currentClassIndex,
    int? currentStudentIndex,
  }) async => {};
  @override
  Future<List<dynamic>> createRecords(
    String taskId,
    List<AttendanceRecord> records,
  ) async => [];
  @override
  Future<void> deleteRecordByTaskStudent(String taskId, int studentId) async {
    deleted.add(studentId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeStudents implements StudentRepository {
  @override
  Future<void> ensureStudentsBatch(List<int> ids) async {}
  @override
  Future<Map<int, ClassInfo>> getClassMap() async => {
    10: const ClassInfo(
      id: 10,
      gradeId: 1,
      majorId: 1,
      classCode: 'A',
      displayName: 'A',
    ),
    20: const ClassInfo(
      id: 20,
      gradeId: 1,
      majorId: 1,
      classCode: 'B',
      displayName: 'B',
    ),
  };
  @override
  Future<Map<int, List<StudentInfo>>> getStudentsByClasses(
    List<int> ids,
  ) async => {
    for (final id in ids)
      id: List.generate(
        3,
        (i) => StudentInfo(
          id: id + i,
          name: 'Student $id-$i',
          studentNo: '$id$i',
          classId: id,
        ),
      ),
  };
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FailedRefresh implements ApiClient {
  @override
  Future<int> getDataVersion() async => 2;
  @override
  Future<List<dynamic>> getGrades() async =>
      throw StateError('network unavailable');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FailingOutbox extends AttendanceLocalDataSource {
  FailingOutbox(super.database);
  @override
  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    throw StateError('simulated full disk');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;
  late AttendanceLocalDataSource local;
  late FakeRemote remote;
  late AttendanceRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase(executor: NativeDatabase.memory());
    local = AttendanceLocalDataSource(database);
    remote = FakeRemote();
    repository = AttendanceRepository(local, remote);
  });
  tearDown(() => database.close());

  Future<AttendanceTask> create({
    TaskType type = TaskType.nameCheck,
    int userId = 1,
  }) => repository.createTask(type: type, classIds: [10, 20], userId: userId);

  test(
    'F03 edit during HTTP has its own row and syncNow drains successor',
    () async {
      await local.enqueueSync(
        entityType: 'record',
        entityId: '1',
        action: 'update',
        payload: {'task_id': 'task', 'student_id': 1, 'status': 'absent'},
      );
      remote.gate = Completer<void>();
      final service = SyncService(local, remote);
      final syncing = service.syncNow();
      await remote.started.future;
      expect(
        (await database.select(database.syncQueue).get()).single.syncStatus,
        'syncing',
      );
      await local.enqueueSync(
        entityType: 'record',
        entityId: '1',
        action: 'update',
        payload: {
          'task_id': 'task',
          'student_id': 1,
          'status': 'present',
          'remark': null,
        },
      );
      expect((await database.select(database.syncQueue).get()).length, 2);
      remote.gate!.complete();
      expect((await syncing).failed, 0);
      expect(remote.statuses, [
        AttendanceStatus.absent,
        AttendanceStatus.present,
      ]);
      expect(await local.getSyncIssueCount(), 0);
      service.dispose();
    },
  );

  test(
    'F03 task patches merge and explicit remark null replaces old value',
    () async {
      await local.enqueueSync(
        entityType: 'task',
        entityId: 't',
        action: 'update',
        payload: {'phase': 'executing'},
      );
      await local.enqueueSync(
        entityType: 'task',
        entityId: 't',
        action: 'update',
        payload: {'current_student_index': 2},
      );
      final taskPatch = jsonDecode(
        (await local.getPendingSyncItems()).single.payload!,
      );
      expect(taskPatch, {'phase': 'executing', 'current_student_index': 2});
      await local.enqueueSync(
        entityType: 'record',
        entityId: 'r',
        action: 'create',
        payload: {'remark': 'old'},
      );
      await local.enqueueSync(
        entityType: 'record',
        entityId: 'r',
        action: 'update',
        payload: {'remark': null},
      );
      final row = (await local.getPendingSyncItems()).last;
      expect(jsonDecode(row.payload!)['remark'], isNull);
      expect(row.action, 'create');
    },
  );

  test('F03 record and outbox commit or roll back together', () async {
    final task = await create();
    final failing = AttendanceRepository(FailingOutbox(database), remote);
    await expectLater(
      failing.createRecord(taskId: task.id, studentId: 10, classId: 10),
      throwsStateError,
    );
    expect(await local.getRecordsByTask(task.id), isEmpty);
  });

  test(
    'F03 legacy failed create and pending successor collapse in revision order',
    () async {
      await database
          .into(database.syncQueue)
          .insert(
            db.SyncQueueCompanion.insert(
              entityType: 'record',
              entityId: '1',
              action: 'create',
              payload: const Value(
                '{"task_id":"t","student_id":1,"class_id":10,"status":"absent"}',
              ),
              syncStatus: const Value('failed'),
              retryCount: const Value(1),
            ),
          );
      await database
          .into(database.syncQueue)
          .insert(
            db.SyncQueueCompanion.insert(
              entityType: 'record',
              entityId: '1',
              action: 'update',
              payload: const Value(
                '{"task_id":"t","student_id":1,"status":"present"}',
              ),
            ),
          );
      await local.enqueueSync(
        entityType: 'record',
        entityId: '1',
        action: 'update',
        payload: {'status': 'late'},
      );
      final pending = await local.getPendingSyncItems();
      expect(pending.length, 1);
      expect(pending.single.action, 'create');
      expect(jsonDecode(pending.single.payload!)['status'], 'late');
      expect(jsonDecode(pending.single.payload!)['class_id'], 10);
    },
  );

  test(
    'F03 interrupted claims recover once when database is reopened',
    () async {
      await database.close();
      final folder = await Directory.systemTemp.createTemp(
        'lesson_search_outbox_test_',
      );
      final file = File('${folder.path}/test.db');
      database = db.AppDatabase(executor: NativeDatabase(file));
      var source = AttendanceLocalDataSource(database);
      await source.enqueueSync(
        entityType: 'task',
        entityId: 't',
        action: 'update',
        payload: {'phase': 'executing'},
      );
      await source.claimPendingSyncItems();
      await source.repairLegacySyncQueue();
      expect(
        (await database.select(database.syncQueue).get()).single.syncStatus,
        'syncing',
      );
      await database.close();
      database = db.AppDatabase(executor: NativeDatabase(file));
      source = AttendanceLocalDataSource(database);
      expect((await source.getPendingSyncItems()).single.syncStatus, 'pending');
      await database.close();
      await folder.delete(recursive: true);
      database = db.AppDatabase(executor: NativeDatabase.memory());
    },
  );

  test('F03 pause waits for HTTP and releases untouched claims', () async {
    for (var id = 1; id <= 2; id++) {
      await local.enqueueSync(
        entityType: 'record',
        entityId: '$id',
        action: 'update',
        payload: {'task_id': 'task', 'student_id': id, 'status': 'absent'},
      );
      // Separate update groups so a batch request is not involved.
      if (id == 1) {
        await local.enqueueSync(
          entityType: 'task',
          entityId: 'separator',
          action: 'update',
          payload: {'phase': 'executing'},
        );
      }
    }
    remote.gate = Completer<void>();
    final service = SyncService(local, remote);
    final syncing = service.processQueueWithStats();
    await remote.started.future;
    var drained = false;
    final pausing = service.pauseAndDrain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, false);
    remote.gate!.complete();
    await pausing;
    await syncing;
    expect(remote.statuses.length, 1);
    expect((await local.getPendingSyncItems()).length, 2);
    expect(
      (await database.select(database.syncQueue).get()).any(
        (r) => r.syncStatus == 'syncing',
      ),
      false,
    );
    service.dispose();
  });

  test(
    'F04 refresh network failure preserves all cached base and student rows',
    () async {
      await database
          .into(database.grades)
          .insert(db.GradesCompanion.insert(name: 'Grade', year: 2026));
      await database
          .into(database.students)
          .insert(
            db.StudentsCompanion.insert(
              name: 'Cached',
              studentNo: '001',
              classId: 10,
            ),
          );
      final repo = StudentRepository(
        database,
        FailedRefresh(),
        await SharedPreferences.getInstance(),
      );
      expect(await repo.checkDataVersion(), false);
      expect(
        (await database.select(database.grades).get()).single.name,
        'Grade',
      );
      expect(
        (await database.select(database.students).get()).single.name,
        'Cached',
      );
    },
  );

  test(
    'F05 saving null B identity clears A real name and optional fields',
    () async {
      final auth = AuthService(await SharedPreferences.getInstance());
      await auth.saveAuth(
        token: 'test-a',
        userId: 1,
        email: 'a@example.test',
        realName: 'A',
        nickname: 'old',
        role: 'admin',
      );
      await auth.clearTokenOnly();
      await auth.saveAuth(token: 'test-b', userId: 2, email: 'b@example.test');
      expect(auth.userRealName, isNull);
      expect(auth.hasRealName, false);
      expect(auth.userNickname, isNull);
      expect(auth.userRole, 'member');
    },
  );

  test(
    'F05 sync bound to B refuses A and unknown ownership without HTTP',
    () async {
      await create(userId: 1);
      final service = SyncService(local, remote, userId: 2);
      final result = await service.syncNow();
      expect(result.failed, greaterThan(0));
      expect(remote.createdOwners, isEmpty);
      service.dispose();
      final bLocal = AttendanceLocalDataSource(database, userId: 2);
      expect(await bLocal.getCompletedNameCheckTasks(), isEmpty);
      expect(await bLocal.getResumableTasks(), isEmpty);
    },
  );

  test(
    'F08 every failed retry tier and active claim blocks submission',
    () async {
      for (var i = 0; i < 3; i++) {
        await local.enqueueSync(
          entityType: 'task',
          entityId: '$i',
          action: 'update',
          payload: {'phase': 'executing'},
        );
      }
      final rows = await local.getPendingSyncItems();
      await local.markSyncFailed(rows[0].id, retryCount: 5);
      await local.markSyncFailed(rows[1].id, retryCount: 999);
      await local.claimPendingSyncItems();
      expect(await local.getSyncIssueCount(), 3);
      expect(await database.getUnsyncedCount(), 3);
      final service = SyncService(local, remote);
      expect((await service.syncNow()).failed, 3);
      service.dispose();
    },
  );

  test('F09 undo removes previous student and syncs actual delete', () async {
    final notifier = RollCallNotifier(repository, FakeStudents());
    await notifier.startRollCall(
      classIds: [10],
      gradeId: 1,
      majorId: 1,
      userId: 1,
    );
    await notifier.nextStudent();
    expect(notifier.state.calledRecordIds.keys, [10]);
    await notifier.prevStudent();
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.calledRecordIds, isEmpty);
    expect(await local.getRecordsByTask(notifier.state.task!.id), isEmpty);
    final service = SyncService(local, remote, userId: 1);
    expect((await service.syncNow()).failed, 0);
    expect(remote.deleted, [10]);
    service.dispose();
    notifier.dispose();
  });

  test('F09 concurrent next taps cannot skip an unrecorded student', () async {
    final notifier = RollCallNotifier(repository, FakeStudents());
    await notifier.startRollCall(
      classIds: [10],
      gradeId: 1,
      majorId: 1,
      userId: 1,
    );
    await Future.wait([notifier.nextStudent(), notifier.nextStudent()]);
    expect(notifier.state.currentIndex, 1);
    expect(notifier.state.calledRecordIds.keys, [10]);
    expect(
      (await local.getRecordsByTask(
        notifier.state.task!.id,
      )).map((r) => r.studentId),
      [10],
    );
    expect(notifier.state.isMutating, false);
    notifier.dispose();
  });

  test(
    'F10 completed confirmation/text resumes, final completion does not',
    () async {
      final notifier = NameCheckNotifier(repository, FakeStudents());
      await notifier.startNameCheck(
        classIds: [10, 20],
        gradeId: 1,
        majorId: 1,
        userId: 1,
      );
      notifier.switchClass(1);
      await notifier.saveProgress();
      final taskId = notifier.state.task!.id;
      final restoring = NameCheckNotifier(repository, FakeStudents());
      await restoring.resumeTask(taskId);
      expect(restoring.state.currentClassIndex, 1);
      expect((await notifier.finishNameCheck()).success, true);
      expect(
        (await repository.getResumableTasks()).single.phase,
        TaskPhase.confirming,
      );
      expect(notifier.state.task!.status, TaskStatus.completed);
      await notifier.advanceToTextGeneration();
      expect(
        (await repository.getResumableTasks()).single.phase,
        TaskPhase.textGenerating,
      );
      await notifier.completeWorkflow();
      expect(await repository.getResumableTasks(), isEmpty);
      expect((await repository.getCompletedNameCheckTasks()).length, 1);
      notifier.dispose();
      restoring.dispose();
    },
  );

  test('F10 saved roll call is resumable', () async {
    final notifier = RollCallNotifier(repository, FakeStudents());
    await notifier.startRollCall(
      classIds: [10],
      gradeId: 1,
      majorId: 1,
      userId: 1,
    );
    await notifier.nextStudent();
    await notifier.saveProgress();
    final saved = (await repository.getResumableTasks()).single;
    expect(saved.type, TaskType.rollCall);
    final restoring = RollCallNotifier(repository, FakeStudents());
    await restoring.resumeTask(saved.id);
    expect(restoring.state.currentIndex, 1);
    expect(restoring.state.calledRecordIds.keys, [10]);
    notifier.dispose();
    restoring.dispose();
  });

  test(
    'F10 home resume stream reacts to saved and finished task changes',
    () async {
      final auth = AuthService(await SharedPreferences.getInstance());
      await auth.saveAuth(token: 'unit', userId: 1, email: 'unit@example.test');
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          databaseProvider.overrideWithValue(database),
          attendanceRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final found = Completer<void>();
      final removed = Completer<void>();
      final subscription = container.listen(resumableTasksProvider, (_, next) {
        final tasks = next.valueOrNull;
        if (tasks == null) return;
        if (tasks.isNotEmpty && !found.isCompleted) found.complete();
        if (tasks.isEmpty && found.isCompleted && !removed.isCompleted) {
          removed.complete();
        }
      }, fireImmediately: true);
      expect(await container.read(resumableTasksProvider.future), isEmpty);
      final task = await create();
      await found.future;
      await repository.updateTaskStatus(
        task,
        status: TaskStatus.completed,
        phase: TaskPhase.finished,
      );
      await removed.future;
      subscription.close();
      container.dispose();
    },
  );

  test(
    'F10 account clearing remains blocked until completed attendance workflow finishes',
    () async {
      final task = await create();
      await repository.updateTaskStatus(
        task,
        status: TaskStatus.completed,
        phase: TaskPhase.confirming,
      );
      await local.clearSyncQueue();
      expect(await database.getUnsyncedCount(), 1);
      await repository.updateTaskStatus(
        task,
        status: TaskStatus.completed,
        phase: TaskPhase.finished,
      );
      await local.clearSyncQueue();
      expect(await database.getUnsyncedCount(), 0);
    },
  );

  test('F21 provider observes sync state changes', () async {
    final service = SyncService(local, remote);
    final container = ProviderContainer(
      overrides: [syncServiceProvider.overrideWithValue(service)],
    );
    final subscription = container.listen(syncStateProvider, (_, _) {});
    expect(container.read(syncStateProvider), SyncState.idle);
    service.state.value = SyncState.syncing;
    expect(container.read(syncStateProvider), SyncState.syncing);
    service.state.value = SyncState.error;
    expect(container.read(syncStateProvider), SyncState.error);
    subscription.close();
    container.dispose();
    service.dispose();
  });

  test(
    'F22 explicit null clears request, models, and persisted record',
    () async {
      expect(recordUpdateRequestBody(AttendanceStatus.present), {
        'status': 'present',
        'remark': null,
      });
      final task = await create();
      final record = await repository.createRecord(
        taskId: task.id,
        studentId: 10,
        classId: 10,
        status: AttendanceStatus.other,
        remark: 'old',
      );
      expect(record.copyWith(remark: null).remark, isNull);
      await repository.updateRecordStatus(record.id!, AttendanceStatus.present);
      expect((await local.getRecordById(record.id!))!.remark, isNull);
      final q = (await local.getPendingSyncItems()).last;
      expect(jsonDecode(q.payload!).containsKey('remark'), true);
      expect(jsonDecode(q.payload!)['remark'], isNull);
      final student = StudentWithStatus(
        student: const StudentInfo(
          id: 1,
          name: 'A',
          studentNo: '1',
          classId: 10,
        ),
        remark: 'old',
      );
      expect(student.copyWith(remark: null).remark, isNull);
      final entry = RecordEntry(
        recordId: 1,
        studentName: 'A',
        studentNo: '1',
        className: 'A',
        status: AttendanceStatus.other,
        remark: 'old',
      );
      expect(entry.copyWith(remark: null).remark, isNull);
    },
  );

  test('HTTP failure never drops an update as falsely synced', () async {
    await local.enqueueSync(
      entityType: 'record',
      entityId: '1',
      action: 'update',
      payload: {'task_id': 'task', 'student_id': 1, 'status': 'absent'},
    );
    remote.error = DioException(
      requestOptions: RequestOptions(path: '/test'),
      type: DioExceptionType.connectionError,
    );
    final service = SyncService(local, remote);
    final result = await service.syncNow();
    expect(result.failed, 1);
    expect(await local.getSyncIssueCount(), 1);
    expect(
      (await database.select(database.syncQueue).get()).single.syncStatus,
      'failed',
    );
    service.dispose();
  });
}
