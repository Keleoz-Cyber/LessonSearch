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
  final int? recordId; // 本地 record id

  const StudentWithStatus({
    required this.student,
    this.status = AttendanceStatus.pending,
    this.recordId,
  });

  StudentWithStatus copyWith({AttendanceStatus? status, int? recordId}) {
    return StudentWithStatus(
      student: student,
      status: status ?? this.status,
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

  /// 初始化记名
  Future<void> startNameCheck({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
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
  Future<void> markStudent(int classId, int studentIndex, AttendanceStatus status) async {
    final task = state.task;
    if (task == null) return;

    final students = List<StudentWithStatus>.from(state.studentsByClass[classId] ?? []);
    if (studentIndex >= students.length) return;

    final student = students[studentIndex];

    if (student.recordId != null) {
      // 已有记录，更新状态
      await _attendanceRepo.updateRecordStatus(student.recordId!, status);
      students[studentIndex] = student.copyWith(status: status);
    } else {
      // 创建新记录
      final record = await _attendanceRepo.createRecord(
        taskId: task.id,
        studentId: student.student.id,
        classId: classId,
        status: status,
      );
      students[studentIndex] = student.copyWith(status: status, recordId: record.id);
    }

    final updatedMap = Map<int, List<StudentWithStatus>>.from(state.studentsByClass);
    updatedMap[classId] = students;
    state = state.copyWith(studentsByClass: updatedMap);
  }

  /// 结束记名
  Future<void> finishNameCheck() async {
    final task = state.task;
    if (task == null) return;

    // 所有未处理的学生标记为 present（已到）
    for (final entry in state.studentsByClass.entries) {
      final classId = entry.key;
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i].status == AttendanceStatus.pending) {
          await markStudent(classId, i, AttendanceStatus.present);
        }
      }
    }

    await _attendanceRepo.updateTaskStatus(
      task,
      status: TaskStatus.completed,
      phase: TaskPhase.confirming,
    );

    state = state.copyWith(isFinished: true);
  }
}
