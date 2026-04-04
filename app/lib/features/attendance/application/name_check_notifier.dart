import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../data/attendance_repository.dart';
import '../../student/data/student_repository.dart';

/// 记名流程状态
class NameCheckState {
  final AttendanceTask? task;
  final List<ClassInfo> classes;
  final int currentClassIndex;
  final Map<int, List<StudentWithStatus>> studentsByClass; // classId → students
  final bool isLoading;
  final bool isFinished;
  final String? error;

  const NameCheckState({
    this.task,
    this.classes = const [],
    this.currentClassIndex = 0,
    this.studentsByClass = const {},
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

  int get totalStudents {
    var count = 0;
    for (final list in studentsByClass.values) {
      count += list.length;
    }
    return count;
  }

  int get processedStudents {
    var count = 0;
    for (final list in studentsByClass.values) {
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
    return NameCheckState(
      task: task ?? this.task,
      classes: classes ?? this.classes,
      currentClassIndex: currentClassIndex ?? this.currentClassIndex,
      studentsByClass: studentsByClass ?? this.studentsByClass,
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

      // 加载班级和学生
      final allClasses = <ClassInfo>[];
      final studentsByClass = <int, List<StudentWithStatus>>{};

      // 加载已有记录
      final existingRecords = await _attendanceRepo.getRecordsByTask(taskId);
      final recordMap = <int, AttendanceRecord>{}; // studentId → record
      for (final r in existingRecords) {
        recordMap[r.studentId] = r;
      }

      final allClassInfos = await _studentRepo.getClasses();

      for (final classId in task.classIds) {
        await _studentRepo.ensureStudentsForClass(classId);
        final students = await _studentRepo.getStudentsByClass(classId);

        final classInfo = allClassInfos.firstWhere((c) => c.id == classId);
        allClasses.add(classInfo);

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
      // 加载所有班级信息和学生
      final allClasses = <ClassInfo>[];
      final studentsByClass = <int, List<StudentWithStatus>>{};

      for (final classId in classIds) {
        await _studentRepo.ensureStudentsForClass(classId);
        final students = await _studentRepo.getStudentsByClass(classId);

        // 获取班级信息
        final classes = await _studentRepo.getClasses();
        final classInfo = classes.firstWhere((c) => c.id == classId);
        allClasses.add(classInfo);

        studentsByClass[classId] = students
            .map((s) => StudentWithStatus(student: s))
            .toList();
      }

      // 创建任务
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

    final students = List<StudentWithStatus>.from(
      state.studentsByClass[classId] ?? [],
    );
    if (studentIndex >= students.length) return;

    final student = students[studentIndex];

    if (student.recordId != null) {
      await _attendanceRepo.updateRecordStatus(
        student.recordId!,
        status,
        remark: remark,
      );
      students[studentIndex] = student.copyWith(status: status, remark: remark);
    } else {
      final record = await _attendanceRepo.createRecord(
        taskId: task.id,
        studentId: student.student.id,
        classId: classId,
        status: status,
        remark: remark,
      );
      students[studentIndex] = student.copyWith(
        status: status,
        remark: remark,
        recordId: record.id,
      );
    }

    final updatedMap = Map<int, List<StudentWithStatus>>.from(
      state.studentsByClass,
    );
    updatedMap[classId] = students;
    state = state.copyWith(studentsByClass: updatedMap);
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
