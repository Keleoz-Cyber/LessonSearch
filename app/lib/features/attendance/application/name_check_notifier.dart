import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger_service.dart';
import '../domain/models.dart';
import '../data/attendance_repository.dart';
import '../../student/data/student_repository.dart';

/// 记名流程状态
class NameCheckState {
  final AttendanceTask? task;
  final List<ClassInfo> classes;
  final int currentClassIndex;
  final Map<int, List<StudentWithStatus>> studentsByClass;
  final int totalStudents;
  final int processedStudents;
  final bool isLoading;
  final bool isFinished;
  final bool isEditing; // 重新编辑模式（从确认页返回）
  final bool isFinishing; // finishNameCheck 正在执行，阻止 markStudent 并发
  final String? error;

  const NameCheckState({
    this.task,
    this.classes = const [],
    this.currentClassIndex = 0,
    this.studentsByClass = const {},
    this.totalStudents = 0,
    this.processedStudents = 0,
    this.isLoading = false,
    this.isFinished = false,
    this.isEditing = false,
    this.isFinishing = false,
    this.error,
  });

  ClassInfo? get currentClass =>
      currentClassIndex < classes.length ? classes[currentClassIndex] : null;

  List<StudentWithStatus> get currentStudents {
    final cls = currentClass;
    if (cls == null) return [];
    return studentsByClass[cls.id] ?? [];
  }

  static int _calcTotal(Map<int, List<StudentWithStatus>> map) {
    var count = 0;
    for (final list in map.values) {
      count += list.length;
    }
    return count;
  }

  static int _calcProcessed(Map<int, List<StudentWithStatus>> map) {
    var count = 0;
    for (final list in map.values) {
      count += list.where((s) => s.status != AttendanceStatus.pending).length;
    }
    return count;
  }

  NameCheckState copyWith({
    AttendanceTask? task,
    List<ClassInfo>? classes,
    int? currentClassIndex,
    Map<int, List<StudentWithStatus>>? studentsByClass,
    bool? isLoading,
    bool? isFinished,
    bool? isEditing,
    bool? isFinishing,
    String? error,
  }) {
    final newStudentsByClass = studentsByClass ?? this.studentsByClass;
    return NameCheckState(
      task: task ?? this.task,
      classes: classes ?? this.classes,
      currentClassIndex: currentClassIndex ?? this.currentClassIndex,
      studentsByClass: newStudentsByClass,
      totalStudents: studentsByClass != null
          ? _calcTotal(newStudentsByClass)
          : totalStudents,
      processedStudents: studentsByClass != null
          ? _calcProcessed(newStudentsByClass)
          : processedStudents,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      isEditing: isEditing ?? this.isEditing,
      isFinishing: isFinishing ?? this.isFinishing,
      error: error,
    );
  }
}

/// 学生 + 当前考勤状态
class StudentWithStatus {
  final StudentInfo student;
  final AttendanceStatus status;
  final String? remark;
  final int? recordId;

  const StudentWithStatus({
    required this.student,
    this.status = AttendanceStatus.pending,
    this.remark,
    this.recordId,
  });

  StudentWithStatus copyWith({
    AttendanceStatus? status,
    String? remark,
    int? recordId,
  }) {
    return StudentWithStatus(
      student: student,
      status: status ?? this.status,
      remark: remark ?? this.remark,
      recordId: recordId ?? this.recordId,
    );
  }
}

/// 按学生 ID 将当前标记状态合并到最新名单。
List<StudentWithStatus> reconcileStudentsWithRoster(
  List<StudentWithStatus> current,
  List<StudentInfo> activeRoster,
) {
  final currentByStudentId = {
    for (final item in current) item.student.id: item,
  };

  return activeRoster.map((student) {
    final existing = currentByStudentId[student.id];
    if (existing == null) {
      return StudentWithStatus(student: student);
    }
    return StudentWithStatus(
      student: student,
      status: existing.status,
      remark: existing.remark,
      recordId: existing.recordId,
    );
  }).toList();
}

/// 记名流程控制器
class NameCheckNotifier extends StateNotifier<NameCheckState> {
  final AttendanceRepository _attendanceRepo;
  final StudentRepository _studentRepo;

  NameCheckNotifier(this._attendanceRepo, this._studentRepo)
    : super(const NameCheckState());

  /// 恢复未完成的记名任务
  Future<void> resumeTask(String taskId) async {
    state = const NameCheckState(isLoading: true);

    try {
      final task = await _attendanceRepo.getTask(taskId);
      if (task == null) {
        state = state.copyWith(isLoading: false, error: '任务不存在');
        return;
      }

      final existingRecords = await _attendanceRepo.getRecordsByTask(taskId);
      final recordMap = <int, AttendanceRecord>{};
      for (final r in existingRecords) {
        recordMap[r.studentId] = r;
      }

      await _studentRepo.ensureStudentsBatch(task.classIds);
      final classMap = await _studentRepo.getClassMap();
      final studentsMap = await _studentRepo.getStudentsByClasses(
        task.classIds,
      );

      final allClasses = <ClassInfo>[];
      final studentsByClass = <int, List<StudentWithStatus>>{};

      for (final classId in task.classIds) {
        final classInfo = classMap[classId];
        if (classInfo == null) continue;
        allClasses.add(classInfo);

        final students = studentsMap[classId] ?? [];
        studentsByClass[classId] = students.map((s) {
          final record = recordMap[s.id];
          return StudentWithStatus(
            student: s,
            status: record != null
                ? AttendanceStatus.fromString(record.status.value)
                : AttendanceStatus.pending,
            remark: record?.remark,
            recordId: record?.id,
          );
        }).toList();
      }

      state = state.copyWith(
        task: task,
        classes: allClasses,
        currentClassIndex: 0,
        studentsByClass: studentsByClass,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
    }
  }

  /// 初始化记名
  Future<void> startNameCheck({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
    int? userId,
  }) async {
    state = const NameCheckState(isLoading: true);

    try {
      await _studentRepo.ensureStudentsBatch(classIds);
      final classMap = await _studentRepo.getClassMap();
      final studentsMap = await _studentRepo.getStudentsByClasses(classIds);

      final allClasses = <ClassInfo>[];
      final studentsByClass = <int, List<StudentWithStatus>>{};

      for (final classId in classIds) {
        final classInfo = classMap[classId];
        if (classInfo == null) continue;
        allClasses.add(classInfo);

        final students = studentsMap[classId] ?? [];
        studentsByClass[classId] = students
            .map((s) => StudentWithStatus(student: s))
            .toList();
      }

      final totalStudents = NameCheckState._calcTotal(studentsByClass);
      if (totalStudents == 0) {
        state = state.copyWith(
          isLoading: false,
          error: '所选班级没有学生数据，请检查网络连接后重试',
        );
        return;
      }

      final task = await _attendanceRepo.createTask(
        type: TaskType.nameCheck,
        classIds: classIds,
        selectedGradeId: gradeId,
        selectedMajorId: majorId,
        userId: userId,
      );

      final updated = await _attendanceRepo.updateTaskStatus(
        task,
        phase: TaskPhase.executing,
      );

      state = state.copyWith(
        task: updated,
        classes: allClasses,
        currentClassIndex: 0,
        studentsByClass: studentsByClass,
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = _formatError(e);
      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  static String _formatError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('timed out') ||
        msg.contains('network') ||
        msg.contains('Network')) {
      return '网络连接失败，请检查网络后重试';
    }
    return '加载失败: $e';
  }

  /// 切换到指定班级
  void switchClass(int index) {
    if (index >= 0 && index < state.classes.length) {
      state = state.copyWith(currentClassIndex: index);
    }
  }

  /// 按稳定学生 ID 标记状态
  Future<void> markStudentById(
    int classId,
    int studentId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    final students = state.studentsByClass[classId];
    if (students == null) return;

    final studentIndex = students.indexWhere((s) => s.student.id == studentId);
    if (studentIndex < 0) return;

    await markStudent(classId, studentIndex, status, remark: remark);
  }

  /// 标记学生状态
  Future<void> markStudent(
    int classId,
    int studentIndex,
    AttendanceStatus status, {
    String? remark,
  }) async {
    final task = state.task;
    if (task == null) return;

    // 防止 finishNameCheck 执行期间并发修改 state
    if (state.isFinishing) return;

    final students = state.studentsByClass[classId];
    if (students == null || studentIndex >= students.length) return;

    final student = students[studentIndex];
    final previousStudent = student; // 保留旧值用于真实回滚

    // 先更新 UI（乐观更新）
    final updatedStudents = List<StudentWithStatus>.from(students);
    updatedStudents[studentIndex] = student.copyWith(
      status: status,
      remark: remark,
      recordId: student.recordId,
    );
    final updatedMap = Map<int, List<StudentWithStatus>>.from(
      state.studentsByClass,
    );
    updatedMap[classId] = updatedStudents;
    state = state.copyWith(studentsByClass: updatedMap);

    // 异步保存到数据库
    try {
      if (student.recordId != null) {
        await _attendanceRepo.updateRecordStatus(
          student.recordId!,
          status,
          remark: remark,
        );
      } else {
        final record = await _attendanceRepo.createRecord(
          taskId: task.id,
          studentId: student.student.id,
          classId: classId,
          status: status,
          remark: remark,
        );
        // 更新 recordId
        final finalStudents = List<StudentWithStatus>.from(
          state.studentsByClass[classId] ?? [],
        );
        if (studentIndex < finalStudents.length &&
            finalStudents[studentIndex].student.id == student.student.id) {
          finalStudents[studentIndex] = finalStudents[studentIndex].copyWith(
            recordId: record.id,
          );
          final finalMap = Map<int, List<StudentWithStatus>>.from(
            state.studentsByClass,
          );
          finalMap[classId] = finalStudents;
          state = state.copyWith(studentsByClass: finalMap);
        }
      }
    } catch (e) {
      // 真实回滚：基于"当前 state"的最新副本，把目标项恢复为旧值，
      // 而不是丢弃后续的并发修改
      LoggerService.error(
        'markStudent 失败，已回滚: classId=$classId, studentId=${student.student.id}, status=${status.value}, error=$e',
      );
      final latest = state.studentsByClass[classId];
      if (latest != null &&
          studentIndex < latest.length &&
          latest[studentIndex].student.id == previousStudent.student.id) {
        final rollbackStudents = List<StudentWithStatus>.from(latest);
        rollbackStudents[studentIndex] = previousStudent;
        final rollbackMap = Map<int, List<StudentWithStatus>>.from(
          state.studentsByClass,
        );
        rollbackMap[classId] = rollbackStudents;
        state = state.copyWith(studentsByClass: rollbackMap);
      }
      // 抛出由调用方（UI）捕获并提示
      rethrow;
    }
  }

  /// 结束记名（批量标记未处理学生为已到）
  ///
  /// 返回值：
  /// - [FinishNameCheckResult.success]：完成并进入确认阶段
  /// - [FinishNameCheckResult.newStudents]：reconcile 后名单变化，新增了未标记学生，
  ///   要求 UI 弹窗，由用户决定是返回标记还是确认全部为"已到"
  /// - [FinishNameCheckResult.failed]：数据库/同步队列写入异常，state.error 已设置
  Future<FinishNameCheckResult> finishNameCheck({
    bool forceMarkPending = false,
  }) async {
    final task = state.task;
    if (task == null) {
      return const FinishNameCheckResult.failed('无任务数据');
    }

    // 标记正在收尾，阻止 markStudent 并发修改
    state = state.copyWith(isFinishing: true);

    try {
      // 记录 reconcile 前的学生 id 集合，用于识别新增学生
      final beforeIdsByClass = <int, Set<int>>{
        for (final e in state.studentsByClass.entries)
          e.key: {for (final s in e.value) s.student.id},
      };

      await _reconcileWithLatestRoster(task);

      // 检测新增学生（reconcile 后存在但 reconcile 前不存在）
      final newStudentsByClass = <int, List<StudentInfo>>{};
      for (final entry in state.studentsByClass.entries) {
        final beforeIds = beforeIdsByClass[entry.key] ?? const <int>{};
        final added = <StudentInfo>[];
        for (final s in entry.value) {
          if (!beforeIds.contains(s.student.id) &&
              s.status == AttendanceStatus.pending) {
            added.add(s.student);
          }
        }
        if (added.isNotEmpty) newStudentsByClass[entry.key] = added;
      }

      // 如果存在新增学生，且未强制结束，返回让 UI 决策
      if (newStudentsByClass.isNotEmpty && !forceMarkPending) {
        return FinishNameCheckResult.newStudents(newStudentsByClass);
      }

      // 收集所有未处理的学生，批量写入
      final pendingItems =
          <({int studentId, int classId, AttendanceStatus status})>[];

      for (final entry in state.studentsByClass.entries) {
        final classId = entry.key;
        final students = entry.value;
        for (final student in students) {
          if (student.status == AttendanceStatus.pending) {
            pendingItems.add((
              studentId: student.student.id,
              classId: classId,
              status: AttendanceStatus.present,
            ));
          }
        }
      }

      // 批量写入 DB + SyncQueue（一个事务），返回 studentId→recordId
      Map<int, int>? recordIdMap;
      if (pendingItems.isNotEmpty) {
        recordIdMap = await _attendanceRepo.createRecordsBatch(
          taskId: task.id,
          items: pendingItems,
        );
      }

      await _attendanceRepo.updateTaskStatus(
        task,
        status: TaskStatus.completed,
        phase: TaskPhase.confirming,
      );

      // 数据库操作成功后，更新 UI 状态（含 recordId 回填）
      final updatedMap = Map<int, List<StudentWithStatus>>.from(
        state.studentsByClass,
      );
      for (final entry in updatedMap.entries) {
        final classId = entry.key;
        final students = List<StudentWithStatus>.from(entry.value);
        for (var i = 0; i < students.length; i++) {
          if (students[i].status == AttendanceStatus.pending) {
            final rid =
                recordIdMap?[students[i].student.id] ?? students[i].recordId;
            students[i] = students[i].copyWith(
              status: AttendanceStatus.present,
              recordId: rid,
            );
          }
        }
        updatedMap[classId] = students;
      }

      state = state.copyWith(studentsByClass: updatedMap, isFinished: true);
      return const FinishNameCheckResult.success();
    } catch (e, st) {
      LoggerService.error('finishNameCheck 失败: $e\n$st');
      // 任务保持 inProgress/executing，避免用户数据丢失
      state = state.copyWith(error: '结束记名失败: ${_formatError(e)}');
      return FinishNameCheckResult.failed(_formatError(e));
    } finally {
      // 无论成功失败，解除 isFinishing 锁
      state = state.copyWith(isFinishing: false);
    }
  }

  Future<void> _reconcileWithLatestRoster(AttendanceTask task) async {
    await _studentRepo.ensureStudentsBatch(task.classIds);
    final studentsMap = await _studentRepo.getStudentsByClasses(task.classIds);
    final reconciledMap = Map<int, List<StudentWithStatus>>.from(
      state.studentsByClass,
    );

    for (final classId in task.classIds) {
      final activeRoster = studentsMap[classId] ?? const <StudentInfo>[];
      final current = state.studentsByClass[classId] ?? const [];
      final reconciled = reconcileStudentsWithRoster(current, activeRoster);
      final activeIds = activeRoster.map((s) => s.id).toSet();
      for (final item in current) {
        if (!activeIds.contains(item.student.id) && item.recordId != null) {
          await _attendanceRepo.deleteRecord(item.recordId!);
        }
      }
      reconciledMap[classId] = reconciled;
    }

    state = state.copyWith(studentsByClass: reconciledMap);
  }

  /// 放弃任务（删除任务和记录）
  Future<void> abandonTask() async {
    final task = state.task;
    if (task == null) return;

    await _attendanceRepo.updateTaskStatus(task, status: TaskStatus.abandoned);

    state = const NameCheckState();
  }

  /// 从确认页返回继续编辑
  void resumeEditing() {
    state = state.copyWith(isFinished: false, isEditing: true);
  }
}

/// finishNameCheck 的结果
class FinishNameCheckResult {
  /// 成功完成
  final bool success;

  /// 因名单变化（新增学生）需要 UI 介入决策；为 null 表示无新增
  final Map<int, List<StudentInfo>>? newStudents;

  /// 失败原因；为 null 表示未失败
  final String? errorMessage;

  const FinishNameCheckResult._({
    required this.success,
    this.newStudents,
    this.errorMessage,
  });

  const FinishNameCheckResult.success() : this._(success: true);

  const FinishNameCheckResult.newStudents(Map<int, List<StudentInfo>> students)
      : this._(success: false, newStudents: students);

  const FinishNameCheckResult.failed(String message)
      : this._(success: false, errorMessage: message);

  bool get hasNewStudents =>
      newStudents != null && newStudents!.isNotEmpty;
  bool get isFailed => errorMessage != null;
}
