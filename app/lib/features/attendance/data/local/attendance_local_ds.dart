import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models.dart' as domain;

/// 封装 Drift 数据库操作，负责 Drift 数据类 <-> 领域模型的转换
class AttendanceLocalDataSource {
  final AppDatabase _db;

  AttendanceLocalDataSource(this._db);

  // ============================================================
  // 任务
  // ============================================================

  Future<void> insertTask(domain.AttendanceTask task) async {
    await _db
        .into(_db.attendanceTasks)
        .insert(
          AttendanceTasksCompanion.insert(
            id: task.id,
            userId: Value(task.userId),
            type: task.type.value,
            status: Value(task.status.value),
            phase: Value(task.phase.value),
            selectedGradeId: Value(task.selectedGradeId),
            selectedMajorId: Value(task.selectedMajorId),
            currentClassIndex: Value(task.currentClassIndex),
            currentStudentIndex: Value(task.currentStudentIndex),
            syncStatus: Value(task.syncStatus.value),
            createdAt: Value(task.createdAt),
            updatedAt: Value(task.updatedAt),
          ),
        );

    for (var i = 0; i < task.classIds.length; i++) {
      await _db
          .into(_db.taskClasses)
          .insert(
            TaskClassesCompanion.insert(
              taskId: task.id,
              classId: task.classIds[i],
              sortOrder: Value(i),
            ),
          );
    }
  }

  Future<void> updateTask(domain.AttendanceTask task) async {
    await (_db.update(
      _db.attendanceTasks,
    )..where((t) => t.id.equals(task.id))).write(
      AttendanceTasksCompanion(
        status: Value(task.status.value),
        phase: Value(task.phase.value),
        currentClassIndex: Value(task.currentClassIndex),
        currentStudentIndex: Value(task.currentStudentIndex),
        syncStatus: Value(task.syncStatus.value),
        updatedAt: Value(task.updatedAt),
      ),
    );
  }

  Future<domain.AttendanceTask?> getTask(String taskId) async {
    final row = await (_db.select(
      _db.attendanceTasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (row == null) return null;

    final classIds = await _getTaskClassIds(taskId);
    return _mapRowToTask(row, classIds);
  }

  Future<List<domain.AttendanceTask>> getTasksByStatus(
    domain.TaskStatus status,
  ) async {
    final rows =
        await (_db.select(_db.attendanceTasks)
              ..where((t) => t.status.equals(status.value))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final tasks = <domain.AttendanceTask>[];
    for (final row in rows) {
      final classIds = await _getTaskClassIds(row.id);
      tasks.add(_mapRowToTask(row, classIds));
    }
    return tasks;
  }

  Future<List<int>> _getTaskClassIds(String taskId) async {
    final rows =
        await (_db.select(_db.taskClasses)
              ..where((tc) => tc.taskId.equals(taskId))
              ..orderBy([(tc) => OrderingTerm.asc(tc.sortOrder)]))
            .get();
    return rows.map((r) => r.classId).toList();
  }

  domain.AttendanceTask _mapRowToTask(AttendanceTask row, List<int> classIds) {
    return domain.AttendanceTask(
      id: row.id,
      userId: row.userId,
      type: domain.TaskType.fromString(row.type),
      status: domain.TaskStatus.fromString(row.status),
      phase: domain.TaskPhase.fromString(row.phase),
      selectedGradeId: row.selectedGradeId,
      selectedMajorId: row.selectedMajorId,
      classIds: classIds,
      currentClassIndex: row.currentClassIndex,
      currentStudentIndex: row.currentStudentIndex,
      syncStatus: domain.SyncStatus.fromString(row.syncStatus),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ============================================================
  // 考勤记录
  // ============================================================

  Future<int> insertRecord(domain.AttendanceRecord record) async {
    return await _db
        .into(_db.attendanceRecords)
        .insert(
          AttendanceRecordsCompanion.insert(
            taskId: record.taskId,
            studentId: record.studentId,
            classId: record.classId,
            status: Value(record.status.value),
            remark: Value(record.remark),
            createdAt: Value(record.createdAt),
            updatedAt: Value(record.updatedAt),
          ),
        );
  }

  /// 批量创建考勤记录（事务内执行）
  Future<List<int>> insertRecordsBatch(
    List<domain.AttendanceRecord> records,
  ) async {
    final ids = <int>[];
    await _db.transaction(() async {
      for (final record in records) {
        final id = await _db
            .into(_db.attendanceRecords)
            .insert(
              AttendanceRecordsCompanion.insert(
                taskId: record.taskId,
                studentId: record.studentId,
                classId: record.classId,
                status: Value(record.status.value),
                remark: Value(record.remark),
                createdAt: Value(record.createdAt),
                updatedAt: Value(record.updatedAt),
              ),
            );
        ids.add(id);
      }
    });
    return ids;
  }

  Future<void> updateRecordStatus(
    int recordId,
    domain.AttendanceStatus status, {
    String? remark,
  }) async {
    await (_db.update(
      _db.attendanceRecords,
    )..where((r) => r.id.equals(recordId))).write(
      AttendanceRecordsCompanion(
        status: Value(status.value),
        remark: Value(remark),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<domain.AttendanceRecord>> getRecordsByTask(String taskId) async {
    final rows =
        await (_db.select(_db.attendanceRecords)
              ..where((r) => r.taskId.equals(taskId))
              ..orderBy([(r) => OrderingTerm.asc(r.id)]))
            .get();
    return rows.map(_mapRowToRecord).toList();
  }

  domain.AttendanceRecord _mapRowToRecord(AttendanceRecord row) {
    return domain.AttendanceRecord(
      id: row.id,
      taskId: row.taskId,
      studentId: row.studentId,
      classId: row.classId,
      status: domain.AttendanceStatus.fromString(row.status),
      remark: row.remark,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ============================================================
  // SyncQueue
  // ============================================================

  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    // 检查是否已存在相同的 pending item
    final existing =
        await (_db.select(_db.syncQueue)..where(
              (s) =>
                  s.entityType.equals(entityType) &
                  s.entityId.equals(entityId) &
                  s.action.equals(action) &
                  s.syncStatus.equals('pending'),
            ))
            .getSingleOrNull();

    if (existing != null) {
      // 更新已有记录的 payload
      await (_db.update(
        _db.syncQueue,
      )..where((s) => s.id.equals(existing.id))).write(
        SyncQueueCompanion(
          payload: Value(payload != null ? jsonEncode(payload) : null),
        ),
      );
    } else {
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              entityType: entityType,
              entityId: entityId,
              action: action,
              payload: Value(payload != null ? jsonEncode(payload) : null),
            ),
          );
    }
  }

  /// 批量入队同步（事务内执行）
  Future<void> enqueueSyncBatch(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db
            .into(_db.syncQueue)
            .insert(
              SyncQueueCompanion.insert(
                entityType: item['entityType'] as String,
                entityId: item['entityId'] as String,
                action: item['action'] as String,
                payload: Value(
                  item['payload'] != null ? jsonEncode(item['payload']) : null,
                ),
              ),
            );
      }
    });
  }

  Future<List<SyncQueueData>> getPendingSyncItems() async {
    return await (_db.select(_db.syncQueue)
          ..where(
            (s) =>
                s.syncStatus.equals('pending') |
                (s.syncStatus.equals('failed') &
                    s.retryCount.isSmallerThanValue(5)),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
  }

  Future<void> markSynced(int syncId) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(syncId))).write(
      SyncQueueCompanion(
        syncStatus: const Value('synced'),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markSyncFailed(int syncId, {int? retryCount}) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(syncId))).write(
      SyncQueueCompanion(
        syncStatus: const Value('failed'),
        retryCount: retryCount != null
            ? Value(retryCount)
            : const Value.absent(),
      ),
    );
  }

  Future<List<SyncQueueData>> getFailedSyncItems() async {
    return await (_db.select(_db.syncQueue)
          ..where(
            (s) =>
                s.syncStatus.equals('failed') &
                s.retryCount.isBiggerOrEqualValue(5),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.id)]))
        .get();
  }

  Future<void> retryAllFailed() async {
    await (_db.update(
      _db.syncQueue,
    )..where((s) => s.syncStatus.equals('failed'))).write(
      const SyncQueueCompanion(
        syncStatus: Value('pending'),
        retryCount: Value(0),
      ),
    );
  }

  Future<void> clearSyncQueue() async {
    await _db.delete(_db.syncQueue).go();
  }
}
