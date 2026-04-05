import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      state = state.copyWith(isLoading: false, error: '恢复失败: $e');
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
      state = state.copyWith(isLoading: false, error: '初始化失败: $e');
    }
  }

  /// 切换到指定班级
  void switchClass(int index) {
    if (index >= 0 && index < state.classes.length) {
      state = state.copyWith(currentClassIndex: index);
    }
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

    final students = state.studentsByClass[classId];
    if (students == null || studentIndex >= students.length) return;

    final student = students[studentIndex];

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
      // 保存失败时回滚
      final rollbackStudents = List<StudentWithStatus>.from(students);
      final rollbackMap = Map<int, List<StudentWithStatus>>.from(
        state.studentsByClass,
      );
      rollbackMap[classId] = rollbackStudents;
      state = state.copyWith(studentsByClass: rollbackMap);
    }
  }

  /// 结束记名（批量标记未处理学生为已到）
  Future<void> finishNameCheck() async {
    final task = state.task;
    if (task == null) return;

    // 收集所有未处理的学生，批量写入
    final pendingItems =
        <({int studentId, int classId, AttendanceStatus status})>[];
    final updatedMap = Map<int, List<StudentWithStatus>>.from(
      state.studentsByClass,
    );

    for (final entry in state.studentsByClass.entries) {
      final classId = entry.key;
      final students = List<StudentWithStatus>.from(entry.value);
      for (var i = 0; i < students.length; i++) {
        if (students[i].status == AttendanceStatus.pending) {
          pendingItems.add((
            studentId: students[i].student.id,
            classId: classId,
            status: AttendanceStatus.present,
          ));
          students[i] = students[i].copyWith(status: AttendanceStatus.present);
        }
      }
      updatedMap[classId] = students;
    }

    // 批量写入 DB + SyncQueue（一个事务）
    if (pendingItems.isNotEmpty) {
      await _attendanceRepo.createRecordsBatch(
        taskId: task.id,
        items: pendingItems,
      );
    }

    await _attendanceRepo.updateTaskStatus(
      task,
      status: TaskStatus.completed,
      phase: TaskPhase.confirming,
    );

    state = state.copyWith(studentsByClass: updatedMap, isFinished: true);
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
    state = state.copyWith(isFinished: false);
  }
}
