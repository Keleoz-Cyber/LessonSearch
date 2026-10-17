import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables.dart' show AttendanceTasks;
import '../../domain/models.dart' as domain;

/// record upsert 结果
class UpsertResult {
  final int id;
  final bool created;
  const UpsertResult({required this.id, required this.created});
}

/// 封装 Drift 数据库操作，负责 Drift 数据类 <-> 领域模型的转换
class AttendanceLocalDataSource {
  final AppDatabase _db;
  final int? userId;

  AttendanceLocalDataSource(this._db, {this.userId});

  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  Expression<bool> _ownerFilter(AttendanceTasks t) =>
      userId == null ? const Constant(true) : t.userId.equals(userId!);

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
    )..where((t) => t.id.equals(taskId) & _ownerFilter(t))).getSingleOrNull();
    if (row == null) return null;

    final classIds = await _getTaskClassIds(taskId);
    return _mapRowToTask(row, classIds);
  }

  Future<List<domain.AttendanceTask>> getTasksByStatus(
    domain.TaskStatus status,
  ) async {
    final rows =
        await (_db.select(_db.attendanceTasks)
              ..where((t) => t.status.equals(status.value) & _ownerFilter(t))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final tasks = <domain.AttendanceTask>[];
    for (final row in rows) {
      final classIds = await _getTaskClassIds(row.id);
      tasks.add(_mapRowToTask(row, classIds));
    }
    return tasks;
  }

  Future<List<domain.AttendanceTask>> getCompletedNameCheckTasks() async {
    final rows =
        await (_db.select(_db.attendanceTasks)
              ..where(
                (t) =>
                    t.status.equals(domain.TaskStatus.completed.value) &
                    t.type.equals('name_check') &
                    _ownerFilter(t),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    final tasks = <domain.AttendanceTask>[];
    for (final row in rows) {
      final classIds = await _getTaskClassIds(row.id);
      tasks.add(_mapRowToTask(row, classIds));
    }
    return tasks;
  }

  Future<List<domain.AttendanceTask>> getResumableTasks() async {
    final rows =
        await (_db.select(_db.attendanceTasks)
              ..where(
                (t) =>
                    _ownerFilter(t) &
                    (t.status.isNotIn(['completed', 'abandoned']) |
                        (t.type.equals('name_check') &
                            t.status.equals('completed') &
                            t.phase.isIn([
                              'executing',
                              'confirming',
                              'text_generating',
                            ]))),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return Future.wait(
      rows.map((r) async => _mapRowToTask(r, await _getTaskClassIds(r.id))),
    );
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

  Future<UpsertResult> insertRecord(domain.AttendanceRecord record) async {
    // 按 taskId + studentId 唯一性检查，已存在则更新而非插入
    final existing =
        await (_db.select(_db.attendanceRecords)
              ..where(
                (r) =>
                    r.taskId.equals(record.taskId) &
                    r.studentId.equals(record.studentId),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.attendanceRecords,
      )..where((r) => r.id.equals(existing.id))).write(
        AttendanceRecordsCompanion(
          status: Value(record.status.value),
          remark: Value(record.remark),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return UpsertResult(id: existing.id, created: false);
    }

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
    return UpsertResult(id: id, created: true);
  }

  /// 批量创建考勤记录（事务内执行），按 taskId+studentId upsert
  /// 返回 `Map<studentId, UpsertResult>`
  Future<Map<int, UpsertResult>> insertRecordsBatch(
    List<domain.AttendanceRecord> records,
  ) async {
    final resultMap = <int, UpsertResult>{};
    await _db.transaction(() async {
      for (final record in records) {
        final result = await insertRecord(record);
        resultMap[record.studentId] = result;
      }
    });
    return resultMap;
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

  /// 删除考勤记录（用于点名撤销）
  Future<void> deleteRecord(int recordId) async {
    await (_db.delete(
      _db.attendanceRecords,
    )..where((r) => r.id.equals(recordId))).go();
    // 取消该 record 的未消费 sync 项（pending create/update）
    // 避免删除后又把已删的数据同步到服务端
    await (_db.update(_db.syncQueue)..where(
          (s) =>
              s.entityType.equals('record') &
              s.entityId.equals(recordId.toString()) &
              s.syncStatus.isIn(['pending', 'failed']),
        ))
        .write(
          const SyncQueueCompanion(
            syncStatus: Value('synced'),
            syncedAt: Value(null),
          ),
        );
  }

  /// 获取单个考勤记录
  Future<domain.AttendanceRecord?> getRecordById(int recordId) async {
    final row = await (_db.select(
      _db.attendanceRecords,
    )..where((r) => r.id.equals(recordId))).getSingleOrNull();
    if (row == null) return null;
    return _mapRowToRecord(row);
  }

  Future<List<domain.AttendanceRecord>> getRecordsByTask(String taskId) async {
    if (userId != null && await getTask(taskId) == null) return [];
    final rows =
        await (_db.select(_db.attendanceRecords)
              ..where((r) => r.taskId.equals(taskId))
              ..orderBy([(r) => OrderingTerm.asc(r.id)]))
            .get();
    return rows.map(_mapRowToRecord).toList();
  }

  /// 清理 taskId+studentId 重复的记录，保留 updatedAt 最新的一条
  /// 返回被清理的重复记录数量
  Future<int> cleanDupRecords() async {
    final allRecords = await _db.select(_db.attendanceRecords).get();
    // 按 (taskId, studentId) 分组，找出重复项
    final groups = <String, List<AttendanceRecord>>{};
    for (final r in allRecords) {
      final key = '${r.taskId}_${r.studentId}';
      groups.putIfAbsent(key, () => []).add(r);
    }
    int removed = 0;
    for (final entry in groups.entries) {
      if (entry.value.length <= 1) continue;
      // 按 updatedAt 降序排列，保留第一条
      entry.value.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      for (var i = 1; i < entry.value.length; i++) {
        final toRemove = entry.value[i];
        await (_db.delete(
          _db.attendanceRecords,
        )..where((r) => r.id.equals(toRemove.id))).go();
        removed++;
      }
    }
    return removed;
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
  }) => _db.transaction(() async {
    // Also collapse duplicate rows left by older app versions. Merge in id
    // order so a stale failed create can never overwrite a newer update.
    final candidates =
        await (_db.select(_db.syncQueue)
              ..where(
                (s) =>
                    s.entityType.equals(entityType) &
                    s.entityId.equals(entityId) &
                    s.syncStatus.isIn(['pending', 'failed']) &
                    (action == 'create' || action == 'update'
                        ? s.action.isIn(['create', 'update'])
                        : s.action.equals(action)),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.id)]))
            .get();
    if (candidates.isNotEmpty) {
      final existing = candidates.first;
      final merged = <String, dynamic>{};
      for (final candidate in candidates) {
        if (candidate.payload == null) continue;
        try {
          merged.addAll(jsonDecode(candidate.payload!) as Map<String, dynamic>);
        } catch (_) {
          // The new edit repairs this payload; do not drop the user's latest
          // valid data just because a legacy predecessor is malformed.
        }
      }
      merged.addAll(payload ?? {});
      final mergedAction =
          action == 'create' || candidates.any((s) => s.action == 'create')
          ? 'create'
          : action;
      await (_db.update(
        _db.syncQueue,
      )..where((s) => s.id.equals(existing.id))).write(
        SyncQueueCompanion(
          action: Value(mergedAction),
          payload: Value(jsonEncode(merged)),
          syncStatus: const Value('pending'),
          retryCount: const Value(0),
        ),
      );
      if (candidates.length > 1) {
        await (_db.update(
          _db.syncQueue,
        )..where((s) => s.id.isIn(candidates.skip(1).map((s) => s.id)))).write(
          SyncQueueCompanion(
            syncStatus: const Value('synced'),
            syncedAt: Value(DateTime.now()),
          ),
        );
      }
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
  });

  /// 批量入队同步（事务内执行）
  Future<void> enqueueSyncBatch(List<Map<String, dynamic>> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await enqueueSync(
          entityType: item['entityType'] as String,
          entityId: item['entityId'] as String,
          action: item['action'] as String,
          payload: item['payload'] as Map<String, dynamic>?,
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

  Future<List<SyncQueueData>> claimPendingSyncItems() =>
      _db.transaction(() async {
        final items = await getPendingSyncItems();
        if (items.isNotEmpty) {
          await (_db.update(_db.syncQueue)
                ..where((s) => s.id.isIn(items.map((i) => i.id))))
              .write(const SyncQueueCompanion(syncStatus: Value('syncing')));
        }
        return items;
      });

  Future<void> releaseClaims(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.syncQueue)
          ..where((s) => s.id.isIn(ids) & s.syncStatus.equals('syncing')))
        .write(const SyncQueueCompanion(syncStatus: Value('pending')));
  }

  Future<int?> getSyncItemOwner(SyncQueueData item) async {
    String? taskId;
    if (item.entityType == 'task') {
      taskId = item.entityId;
    } else {
      try {
        taskId =
            (jsonDecode(item.payload ?? '{}')
                    as Map<String, dynamic>)['task_id']
                as String?;
      } catch (_) {}
    }
    if (taskId == null) return null;
    final task = await (_db.select(
      _db.attendanceTasks,
    )..where((t) => t.id.equals(taskId!))).getSingleOrNull();
    return task?.userId;
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
    // 只重置非认证过期的 failed 项（排除 retryCount=999 的 401 项）
    // 401 项需要用户重新登录后通过 resetAuthFailedSyncItems() 重置
    await (_db.update(_db.syncQueue)..where(
          (s) =>
              s.syncStatus.equals('failed') &
              s.retryCount.isSmallerThanValue(999),
        ))
        .write(
          const SyncQueueCompanion(
            syncStatus: Value('pending'),
            retryCount: Value(0),
          ),
        );
  }

  /// 重置因 401（认证过期）标记为 failed(retryCount=999) 的同步项，恢复为 pending
  /// 在重新登录成功后调用，让这些项能继续同步
  Future<int> resetAuthFailedSyncItems() async {
    final stmt = _db.update(_db.syncQueue)
      ..where((s) => s.syncStatus.equals('failed') & s.retryCount.equals(999));
    final companion = const SyncQueueCompanion(
      syncStatus: Value('pending'),
      retryCount: Value(0),
    );
    final affected = await stmt.write(companion);
    return affected;
  }

  /// 重置已放弃（retryCount>=5 且 <999）的同步项，恢复为 pending
  /// 在同步问题详情页点击"立即重试"时调用
  Future<int> resetGivenUpSyncItems() async {
    final stmt = _db.update(_db.syncQueue)
      ..where(
        (s) =>
            s.syncStatus.equals('failed') &
            s.retryCount.isBiggerOrEqualValue(5) &
            s.retryCount.isSmallerThanValue(999),
      );
    final companion = const SyncQueueCompanion(
      syncStatus: Value('pending'),
      retryCount: Value(0),
    );
    final affected = await stmt.write(companion);
    return affected;
  }

  Future<void> clearSyncQueue() async {
    await _db.delete(_db.syncQueue).go();
  }

  /// 修复旧版本升级遗留的 SyncQueue 问题（幂等，可重复执行）
  /// 返回修复统计：{syncing, badPayload, incompleteRecord, cleanedSynced}
  Future<Map<String, int>> repairLegacySyncQueue() async {
    int fixedSyncing = 0;
    int skippedBadPayload = 0;
    int skippedIncomplete = 0;
    int cleanedSynced = 0;

    final all = await _db.select(_db.syncQueue).get();

    for (final item in all) {
      // 跳过 auth_failed 项（401 登录过期），留给 resetAuthFailedSyncItems() 处理
      if (item.syncStatus == 'failed' && item.retryCount == 999) {
        continue;
      }

      if (item.syncStatus == 'syncing' || item.syncStatus == 'synced') continue;

      // 只处理 pending 和 failed（非 999）的 record/update
      if (item.entityType == 'record' && item.action == 'update') {
        // 2. payload 为空或解析失败
        if (item.payload == null || item.payload!.isEmpty) {
          await markSyncFailed(item.id, retryCount: 998);
          skippedBadPayload++;
          continue;
        }

        try {
          final payload = jsonDecode(item.payload!) as Map<String, dynamic>;

          // 3. record/update 缺少必要字段
          final hasTaskId =
              payload.containsKey('task_id') && payload['task_id'] != null;
          final hasStudentId =
              payload.containsKey('student_id') &&
              payload['student_id'] != null;
          final hasStatus =
              payload.containsKey('status') && payload['status'] != null;

          if (!hasTaskId || !hasStudentId || !hasStatus) {
            await markSyncFailed(item.id, retryCount: 998);
            skippedIncomplete++;
            continue;
          }
        } catch (_) {
          // JSON 解析失败，标记为 synced
          await markSyncFailed(item.id, retryCount: 998);
          skippedBadPayload++;
          continue;
        }
      }
    }

    // 4. 清理 7 天前已 synced 的历史队列项
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final oldSynced =
        await (_db.select(_db.syncQueue)..where(
              (s) =>
                  s.syncStatus.equals('synced') &
                  s.createdAt.isSmallerThanValue(sevenDaysAgo),
            ))
            .get();
    for (final item in oldSynced) {
      await (_db.delete(
        _db.syncQueue,
      )..where((s) => s.id.equals(item.id))).go();
      cleanedSynced++;
    }

    // 5. 清理 taskId+studentId 重复的 attendance_records
    final dupRemoved = await cleanDupRecords();

    return {
      'syncing': fixedSyncing,
      'badPayload': skippedBadPayload,
      'incompleteRecord': skippedIncomplete,
      'cleanedSynced': cleanedSynced,
      'dupRecords': dupRemoved,
    };
  }

  /// 获取同步问题数量（pending + failed，包括所有 failed）
  Future<int> getSyncIssueCount() async {
    final all = await _db.select(_db.syncQueue).get();
    return all.where((s) => s.syncStatus != 'synced').length;
  }

  /// 判断是否存在 syncStatus == 'failed' 的记录
  Future<bool> hasSyncFailedItems() async {
    final all = await _db.select(_db.syncQueue).get();
    return all.any((s) => s.syncStatus == 'failed');
  }

  /// 返回 pending + failed，用于同步问题详情页展示
  Future<List<SyncQueueData>> getSyncIssueItems() async {
    return await (_db.select(_db.syncQueue)
          ..where((s) => s.syncStatus.isNotIn(['synced']))
          ..orderBy([(s) => OrderingTerm.asc(s.id)]))
        .get();
  }
}
