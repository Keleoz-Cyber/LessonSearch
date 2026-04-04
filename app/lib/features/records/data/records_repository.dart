import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../attendance/domain/models.dart' as domain;

/// 查课记录汇总信息
class TaskSummary {
  final String id;
  final domain.TaskType type;
  final domain.TaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> classNames;
  final int totalStudents;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final int otherCount;

  const TaskSummary({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.classNames,
    required this.totalStudents,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.otherCount,
  });

  String get typeLabel => type == domain.TaskType.rollCall ? '点名' : '记名';
  int get presentCount => totalStudents - absentCount - leaveCount - otherCount;
}

/// 记录详情中的学生条目
class RecordEntry {
  final int recordId;
  final String studentName;
  final String studentNo;
  final String className;
  final domain.AttendanceStatus status;
  final String? remark;

  const RecordEntry({
    required this.recordId,
    required this.studentName,
    required this.studentNo,
    required this.className,
    required this.status,
    this.remark,
  });
}

/// 查课记录数据访问
class RecordsRepository {
  final AppDatabase _db;

  RecordsRepository(this._db);

  /// 获取所有已完成/已放弃的任务摘要
  Future<List<TaskSummary>> getTaskSummaries() async {
    final tasks = await (_db.select(_db.attendanceTasks)
          ..where((t) => t.status.isIn(['in_progress', 'completed', 'abandoned']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (tasks.isEmpty) return [];

    // 预加载所有班级名（避免 N+1）
    final allClasses = await _db.select(_db.classes).get();
    final classMap = {for (final c in allClasses) c.id: c.displayName};

    final summaries = <TaskSummary>[];
    for (final task in tasks) {
      final taskClasses = await (_db.select(_db.taskClasses)
            ..where((tc) => tc.taskId.equals(task.id)))
          .get();
      final classNames = taskClasses
          .map((tc) => classMap[tc.classId] ?? '未知')
          .toList();

      // 统计班级学生总数
      var classStudentTotal = 0;
      for (final tc in taskClasses) {
        final count = await (_db.select(_db.students)
              ..where((s) => s.classId.equals(tc.classId)))
            .get();
        classStudentTotal += count.length;
      }

      // 统计记录
      final records = await (_db.select(_db.attendanceRecords)
            ..where((r) => r.taskId.equals(task.id)))
          .get();

      var absent = 0, late_ = 0, leave = 0, other = 0, present = 0;
      for (final r in records) {
        switch (r.status) {
          case 'absent':
            absent++;
          case 'late':
            late_++;
          case 'leave':
            leave++;
          case 'other':
            other++;
          case 'present':
            present++;
        }
      }

      // 点名：总数用班级学生数；记名：总数用记录数
      final isRollCall = task.type == 'roll_call';
      final total = isRollCall ? classStudentTotal : records.length;

      summaries.add(TaskSummary(
        id: task.id,
        type: domain.TaskType.fromString(task.type),
        status: domain.TaskStatus.fromString(task.status),
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        classNames: classNames,
        totalStudents: total,
        absentCount: isRollCall ? (total - present) : absent,
        lateCount: isRollCall ? 0 : late_,
        leaveCount: isRollCall ? 0 : leave,
        otherCount: isRollCall ? 0 : other,
      ));
    }

    return summaries;
  }

  /// 获取任务的所有记录详情
  Future<List<RecordEntry>> getRecordEntries(String taskId) async {
    final records = await (_db.select(_db.attendanceRecords)
          ..where((r) => r.taskId.equals(taskId))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();

    final entries = <RecordEntry>[];
    for (final r in records) {
      final student = await (_db.select(_db.students)
            ..where((s) => s.id.equals(r.studentId)))
          .getSingleOrNull();
      final cls = await (_db.select(_db.classes)
            ..where((c) => c.id.equals(r.classId)))
          .getSingleOrNull();

      entries.add(RecordEntry(
        recordId: r.id,
        studentName: student?.name ?? '未知',
        studentNo: student?.studentNo ?? '',
        className: cls?.displayName ?? '',
        status: domain.AttendanceStatus.fromString(r.status),
        remark: r.remark,
      ));
    }

    return entries;
  }

  /// 更新记录状态
  Future<void> updateRecord(int recordId, domain.AttendanceStatus status, {String? remark}) async {
    await (_db.update(_db.attendanceRecords)
          ..where((r) => r.id.equals(recordId)))
        .write(AttendanceRecordsCompanion(
      status: Value(status.value),
      remark: Value(remark),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 获取任务关联的所有班级学生（用于点名记录显示全员）
  Future<List<RecordEntry>> getFullRollCallEntries(String taskId) async {
    // 获取任务关联的班级
    final taskClasses = await (_db.select(_db.taskClasses)
          ..where((tc) => tc.taskId.equals(taskId))
          ..orderBy([(tc) => OrderingTerm.asc(tc.sortOrder)]))
        .get();

    // 获取已有记录
    final existingRecords = await (_db.select(_db.attendanceRecords)
          ..where((r) => r.taskId.equals(taskId)))
        .get();
    final calledStudentIds = {for (final r in existingRecords) r.studentId};

    final entries = <RecordEntry>[];

    for (final tc in taskClasses) {
      final cls = await (_db.select(_db.classes)
            ..where((c) => c.id.equals(tc.classId)))
          .getSingleOrNull();
      final className = cls?.displayName ?? '';

      final students = await (_db.select(_db.students)
            ..where((s) => s.classId.equals(tc.classId))
            ..orderBy([(s) => OrderingTerm.asc(s.studentNo)]))
          .get();

      for (final s in students) {
        final called = calledStudentIds.contains(s.id);
        entries.add(RecordEntry(
          recordId: 0,
          studentName: s.name,
          studentNo: s.studentNo,
          className: className,
          status: called ? domain.AttendanceStatus.present : domain.AttendanceStatus.pending,
        ));
      }
    }

    return entries;
  }

  /// 删除任务及其记录
  Future<void> deleteTask(String taskId) async {
    await (_db.delete(_db.attendanceRecords)
          ..where((r) => r.taskId.equals(taskId)))
        .go();
    await (_db.delete(_db.taskClasses)
          ..where((tc) => tc.taskId.equals(taskId)))
        .go();
    await (_db.delete(_db.attendanceTasks)
          ..where((t) => t.id.equals(taskId)))
        .go();
  }
}
