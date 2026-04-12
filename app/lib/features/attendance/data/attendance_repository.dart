import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'local/attendance_local_ds.dart';
import 'remote/attendance_remote_ds.dart';

/// 统一数据访问层：写本地 → 入队 SyncQueue
///
/// 所有业务操作通过此类进行，页面层不直接操作数据库或 API。
class AttendanceRepository {
  final AttendanceLocalDataSource _local;
  final AttendanceRemoteDataSource _remote;
  static const _uuid = Uuid();

  AttendanceRepository(this._local, this._remote);

  // ============================================================
  // 任务
  // ============================================================

  /// 创建任务：写入 Drift + 入队同步
  Future<AttendanceTask> createTask({
    required TaskType type,
    required List<int> classIds,
    int? selectedGradeId,
    int? selectedMajorId,
    int? userId,
  }) async {
    final now = DateTime.now();
    final task = AttendanceTask(
      id: _uuid.v4(),
      userId: userId,
      type: type,
      classIds: classIds,
      selectedGradeId: selectedGradeId,
      selectedMajorId: selectedMajorId,
      createdAt: now,
      updatedAt: now,
    );

    await _local.insertTask(task);
    await _local.enqueueSync(
      entityType: 'task',
      entityId: task.id,
      action: 'create',
      payload: userId != null ? {'user_id': userId} : null,
    );

    return task;
  }

  /// 更新任务状态：写入 Drift + 入队同步
  Future<AttendanceTask> updateTaskStatus(
    AttendanceTask task, {
    TaskStatus? status,
    TaskPhase? phase,
    int? currentClassIndex,
    int? currentStudentIndex,
  }) async {
    final updated = task.copyWith(
      status: status,
      phase: phase,
      currentClassIndex: currentClassIndex,
      currentStudentIndex: currentStudentIndex,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await _local.updateTask(updated);
    await _local.enqueueSync(
      entityType: 'task',
      entityId: task.id,
      action: 'update',
      payload: {
        if (status != null) 'status': status.value,
        if (phase != null) 'phase': phase.value,
        if (currentClassIndex != null) 'current_class_index': currentClassIndex,
        if (currentStudentIndex != null)
          'current_student_index': currentStudentIndex,
      },
    );

    return updated;
  }

  /// 获取任务
  Future<AttendanceTask?> getTask(String taskId) {
    return _local.getTask(taskId);
  }

  /// 获取未完成的任务（用于中断恢复）
  Future<List<AttendanceTask>> getInProgressTasks() {
    return _local.getTasksByStatus(TaskStatus.inProgress);
  }

  /// 获取已完成的记名任务（用于提交审核）
  Future<List<AttendanceTask>> getCompletedNameCheckTasks() {
    return _local.getCompletedNameCheckTasks();
  }

  // ============================================================
  // 考勤记录
  // ============================================================

  /// 创建单条考勤记录：写入 Drift + 入队同步
  Future<AttendanceRecord> createRecord({
    required String taskId,
    required int studentId,
    required int classId,
    AttendanceStatus status = AttendanceStatus.pending,
    String? remark,
  }) async {
    final now = DateTime.now();
    final record = AttendanceRecord(
      taskId: taskId,
      studentId: studentId,
      classId: classId,
      status: status,
      remark: remark,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _local.insertRecord(record);
    final saved = record.copyWith(id: id);

    await _local.enqueueSync(
      entityType: 'record',
      entityId: id.toString(),
      action: 'create',
      payload: {
        'task_id': taskId,
        'student_id': studentId,
        'class_id': classId,
        'status': status.value,
      },
    );

    return saved;
  }

  /// 更新考勤记录状态：写入 Drift + 入队同步
  Future<void> updateRecordStatus(
    int recordId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    await _local.updateRecordStatus(recordId, status, remark: remark);
    await _local.enqueueSync(
      entityType: 'record',
      entityId: recordId.toString(),
      action: 'update',
      payload: {'status': status.value, if (remark != null) 'remark': remark},
    );
  }

  /// 删除单条考勤记录（用于点名撤销）
  Future<void> deleteRecord(int recordId) async {
    await _local.deleteRecord(recordId);
    await _local.enqueueSync(
      entityType: 'record',
      entityId: recordId.toString(),
      action: 'delete',
      payload: {},
    );
  }

  /// 获取任务的所有记录
  Future<List<AttendanceRecord>> getRecordsByTask(String taskId) {
    return _local.getRecordsByTask(taskId);
  }

  /// 批量创建考勤记录（用于 finishNameCheck 等场景）
  Future<void> createRecordsBatch({
    required String taskId,
    required List<({int studentId, int classId, AttendanceStatus status})>
    items,
  }) async {
    final now = DateTime.now();
    final records = items
        .map(
          (item) => AttendanceRecord(
            taskId: taskId,
            studentId: item.studentId,
            classId: item.classId,
            status: item.status,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    final ids = await _local.insertRecordsBatch(records);

    final syncItems = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i++) {
      syncItems.add({
        'entityType': 'record',
        'entityId': ids[i].toString(),
        'action': 'create',
        'payload': {
          'task_id': taskId,
          'student_id': items[i].studentId,
          'class_id': items[i].classId,
          'status': items[i].status.value,
        },
      });
    }
    await _local.enqueueSyncBatch(syncItems);
  }
}
