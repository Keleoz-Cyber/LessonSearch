import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Grades,
    Majors,
    Classes,
    Students,
    AttendanceTasks,
    TaskClasses,
    AttendanceRecords,
    SyncQueue,
    DutyPlanRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (_) async {
        // A claim only belongs to the process that made it. Recover interrupted
        // work once when opening the database, never during a live sync pass.
        await customUpdate(
          "UPDATE sync_queue SET sync_status = 'pending' WHERE sync_status = 'syncing'",
          updates: {syncQueue},
        );
      },
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          try {
            await m.createTable(users);
          } catch (_) {}
          try {
            await m.addColumn(attendanceTasks, attendanceTasks.userId);
          } catch (e) {
            // 列已存在是正常情况，其他异常往上抛
            if (!e.toString().contains('duplicate column')) rethrow;
          }
        }
        if (from < 3) {
          try {
            await m.createTable(dutyPlanRows);
          } catch (_) {}
        }
        if (from < 4) {
          try {
            await m.addColumn(dutyPlanRows, dutyPlanRows.classroom);
          } catch (e) {
            if (!e.toString().contains('duplicate column')) rethrow;
          }
        }
        if (from < 5) {
          // Upgrading directly from v1/v2 creates the current duty-plan table
          // above, so these columns may already exist even on an old version.
          final dutyColumns = {
            for (final row in await customSelect(
              'PRAGMA table_info(duty_plan_rows)',
            ).get())
              row.read<String>('name'),
          };
          if (!dutyColumns.contains('reminder_status')) {
            await m.addColumn(dutyPlanRows, dutyPlanRows.reminderStatus);
          }
          if (!dutyColumns.contains('reminder_error')) {
            await m.addColumn(dutyPlanRows, dutyPlanRows.reminderError);
          }
          await transaction(() async {
            // v4 never persisted a final workflow phase after copying text.
            // A completed legacy task cannot distinguish an interrupted review
            // from years of finished history. Close both without changing any
            // attendance data; records remain available for text regeneration.
            final terminalTasks = await (select(
              attendanceTasks,
            )..where((t) => t.status.isIn(['completed', 'abandoned']))).get();
            final terminalById = {
              for (final task in terminalTasks) task.id: task,
            };
            if (terminalById.isEmpty) return;
            await (update(
              attendanceTasks,
            )..where((t) => t.id.isIn(terminalById.keys))).write(
              const AttendanceTasksCompanion(phase: Value('finished')),
            );
            final queuedTasks =
                await (select(syncQueue)..where(
                      (q) =>
                          q.entityType.equals('task') &
                          q.entityId.isIn(terminalById.keys) &
                          q.action.isIn(['create', 'update']) &
                          q.syncStatus.isNotIn(['synced']),
                    ))
                    .get();
            for (final item in queuedTasks) {
              final payload = <String, dynamic>{};
              try {
                if (item.payload != null) {
                  payload.addAll(
                    jsonDecode(item.payload!) as Map<String, dynamic>,
                  );
                }
              } catch (_) {
                // Task creates read the full persisted task at send time;
                // terminal update metadata is recoverable even from bad JSON.
              }
              payload['status'] = terminalById[item.entityId]!.status;
              payload['phase'] = 'finished';
              await (update(
                syncQueue,
              )..where((q) => q.id.equals(item.id))).write(
                SyncQueueCompanion(payload: Value(jsonEncode(payload))),
              );
            }
          });
        }
      },
    );
  }

  Future<void> clearUserData() async {
    await transaction(() async {
      await delete(syncQueue).go();
      await delete(attendanceRecords).go();
      await delete(taskClasses).go();
      await delete(attendanceTasks).go();
      await delete(dutyPlanRows).go();
      await delete(users).go();
      await delete(students).go();
      await delete(classes).go();
      await delete(majors).go();
      await delete(grades).go();
    });
  }

  Future<int> getUnsyncedCount() async {
    var count = 0;
    // 只统计真正未同步的数据：pending 和 failed（无论 retryCount）
    // 不统计已同步成功的（synced）记录，避免历史队列积累导致误判
    final queueQuery = select(syncQueue)
      ..where((s) => s.syncStatus.isNotIn(['synced']));
    final queueList = await queueQuery.get();
    count += queueList.length;
    final unfinishedQuery = select(attendanceTasks)
      ..where(
        (t) =>
            t.status.isNotIn(['completed', 'abandoned']) |
            (t.type.equals('name_check') &
                t.status.equals('completed') &
                t.phase.isIn(['executing', 'confirming', 'text_generating'])),
      );
    final unfinishedList = await unfinishedQuery.get();
    count += unfinishedList.length;
    return count;
  }

  /// 获取数据统计
  Future<Map<String, int>> getStatistics() async {
    final taskCount = await select(attendanceTasks).get();
    final recordCount = await select(attendanceRecords).get();
    final pendingSyncQuery = select(syncQueue)
      ..where(
        (s) =>
            s.syncStatus.equals('pending') |
            (s.syncStatus.equals('failed') &
                s.retryCount.isSmallerThanValue(5)),
      );
    final pendingSyncCount = await pendingSyncQuery.get();
    final completedTasks = taskCount
        .where((t) => t.status == 'completed')
        .length;
    final abandonedTasks = taskCount
        .where((t) => t.status == 'abandoned')
        .length;
    final inProgressTasks = taskCount
        .where((t) => t.status == 'in_progress')
        .length;

    return {
      'total_tasks': taskCount.length,
      'completed_tasks': completedTasks,
      'abandoned_tasks': abandonedTasks,
      'in_progress_tasks': inProgressTasks,
      'total_records': recordCount.length,
      'pending_sync': pendingSyncCount.length,
    };
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lesson_search.db'));
    return NativeDatabase.createInBackground(file);
  });
}
