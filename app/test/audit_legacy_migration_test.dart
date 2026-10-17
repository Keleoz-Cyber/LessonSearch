import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// A real complete pre-upgrade schema, shared between two Drift connections.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:lesson_search/core/database/app_database.dart';
import 'package:lesson_search/features/attendance/data/local/attendance_local_ds.dart';

void main() {
  test(
    'complete v2 database upgrades through current duty table creation without duplicate columns',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      final fixture = AppDatabase(
        executor: NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      await fixture.customSelect('SELECT COUNT(*) FROM attendance_tasks').get();
      // The v2 schema has users/user_id but does not yet have duty_plan_rows.
      await fixture.customStatement('DROP TABLE duty_plan_rows');
      await fixture.customStatement('PRAGMA user_version = 2');
      await fixture.customStatement('''
      INSERT INTO attendance_tasks(id,user_id,type,status,phase)
      VALUES ('v2-history',1,'name_check','completed','confirming')
    ''');
      await fixture.close();
      final upgraded = AppDatabase(executor: NativeDatabase.opened(raw));
      try {
        final old =
            (await upgraded.select(upgraded.attendanceTasks).get()).single;
        expect(old.id, 'v2-history');
        expect(old.phase, 'finished');
        expect(await upgraded.getUnsyncedCount(), 0);
        final columns =
            (await upgraded
                    .customSelect('PRAGMA table_info(duty_plan_rows)')
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(
          columns,
          containsAll(['classroom', 'reminder_status', 'reminder_error']),
        );
        await upgraded.customStatement('''
        INSERT INTO duty_plan_rows(id,week_number,weekday,period,class_ids,notification_id,class_start_at)
        VALUES ('new-plan',1,1,1,'[10]',123,1800000000)
      ''');
        final plan =
            (await upgraded.select(upgraded.dutyPlanRows).get()).single;
        expect(plan.reminderStatus, 'unknown');
        expect(plan.reminderError, isNull);
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
    'v4 migration closes legacy terminal history and normalizes only its queued task patches',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      final fixture = AppDatabase(
        executor: NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      // Generate every real table first, then remove only the v5 columns and
      // rewind user_version. This is a complete v4 database, not a partial mock.
      await fixture.customSelect('SELECT COUNT(*) FROM attendance_tasks').get();
      await fixture.customStatement(
        'ALTER TABLE duty_plan_rows DROP COLUMN reminder_status',
      );
      await fixture.customStatement(
        'ALTER TABLE duty_plan_rows DROP COLUMN reminder_error',
      );
      await fixture.customStatement('PRAGMA user_version = 4');
      for (final row in [
        ['completed-review', 'name_check', 'completed', 'confirming'],
        ['completed-text', 'name_check', 'completed', 'text_generating'],
        ['completed-roll', 'roll_call', 'completed', 'confirming'],
        ['abandoned', 'name_check', 'abandoned', 'executing'],
        ['live-name', 'name_check', 'in_progress', 'executing'],
        ['live-roll', 'roll_call', 'in_progress', 'executing'],
      ]) {
        await fixture.customStatement('''
        INSERT INTO attendance_tasks(id,user_id,type,status,phase,current_class_index,current_student_index,created_at,updated_at)
        VALUES (?,1,?,?,?,1,2,1700000000,1700000001)
      ''', row);
      }
      await fixture.customStatement('''
      INSERT INTO attendance_records(task_id,student_id,class_id,status,remark,created_at,updated_at)
      VALUES ('completed-review',77,10,'other','keep attendance data',1700000000,1700000001)
    ''');
      final queued = [
        [
          'task',
          'completed-review',
          'update',
          '{"phase":"confirming","current_class_index":1}',
          'pending',
          0,
        ],
        [
          'task',
          'completed-text',
          'create',
          '{"phase":"executing","status":"in_progress","user_id":1}',
          'failed',
          999,
        ],
        [
          'task',
          'abandoned',
          'update',
          '{"phase":"executing","status":"completed"}',
          'syncing',
          2,
        ],
        ['task', 'completed-roll', 'update', 'bad json', 'failed', 5],
        [
          'task',
          'live-name',
          'update',
          '{"phase":"executing","current_class_index":1}',
          'pending',
          0,
        ],
        [
          'record',
          '77',
          'update',
          '{"task_id":"completed-review","student_id":77,"status":"other","remark":"keep attendance data"}',
          'pending',
          0,
        ],
        [
          'task',
          'completed-review',
          'update',
          '{"phase":"confirming"}',
          'synced',
          0,
        ],
      ];
      for (final row in queued) {
        await fixture.customStatement('''
        INSERT INTO sync_queue(entity_type,entity_id,action,payload,sync_status,retry_count)
        VALUES (?,?,?,?,?,?)
      ''', row);
      }
      await fixture.close();

      final upgraded = AppDatabase(executor: NativeDatabase.opened(raw));
      try {
        final tasks = await upgraded.select(upgraded.attendanceTasks).get();
        for (final task in tasks) {
          expect(
            task.phase,
            task.status == 'in_progress' ? 'executing' : 'finished',
          );
          expect(task.currentClassIndex, 1);
          expect(task.currentStudentIndex, 2);
          expect(task.createdAt.millisecondsSinceEpoch ~/ 1000, 1700000000);
          expect(task.updatedAt.millisecondsSinceEpoch ~/ 1000, 1700000001);
        }
        final record =
            (await upgraded.select(upgraded.attendanceRecords).get()).single;
        expect(record.status, 'other');
        expect(record.remark, 'keep attendance data');
        expect(record.studentId, 77);
        final queue = await upgraded.select(upgraded.syncQueue).get();
        expect(queue.length, queued.length);
        for (var i = 0; i < 4; i++) {
          final payload = jsonDecode(queue[i].payload!) as Map;
          expect(payload['phase'], 'finished');
          expect(payload['status'], i == 2 ? 'abandoned' : 'completed');
        }
        expect(jsonDecode(queue[0].payload!)['current_class_index'], 1);
        expect(jsonDecode(queue[1].payload!)['user_id'], 1);
        expect(queue[1].retryCount, 999);
        expect(queue[2].syncStatus, 'pending'); // interrupted claim recovery
        expect(queue[2].retryCount, 2);
        expect(queue[3].retryCount, 5);
        for (var i = 4; i < queued.length; i++) {
          expect(queue[i].payload, queued[i][3]);
        }
        final local = AttendanceLocalDataSource(upgraded, userId: 1);
        expect((await local.getResumableTasks()).map((t) => t.id).toSet(), {
          'live-name',
          'live-roll',
        });
        // Seven real outbox rows minus the one already synced, plus two live
        // tasks. The four historical terminal tasks must not add logout blockers.
        expect(await upgraded.getUnsyncedCount(), 8);
        await local.clearSyncQueue();
        expect(await upgraded.getUnsyncedCount(), 2);
        await upgraded.customUpdate(
          "UPDATE attendance_tasks SET status='completed',phase='finished' WHERE status='in_progress'",
        );
        expect(await upgraded.getUnsyncedCount(), 0);
        final version = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 5);
      } finally {
        await upgraded.close();
      }
    },
  );
}
