import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../data/attendance_repository.dart';
import '../../student/data/student_repository.dart';

/// 点名流程状态
class RollCallState {
  final AttendanceTask? task;
  final List<StudentInfo> students; // 所有班级的学生按学号排序
  final Map<int, String> classNameMap; // classId → displayName
  final int currentIndex;
  final bool isLoading;
  final bool isFinished;
  final String? error;

  const RollCallState({
    this.task,
    this.students = const [],
    this.classNameMap = const {},
    this.currentIndex = 0,
    this.isLoading = false,
    this.isFinished = false,
    this.error,
  });

  StudentInfo? get currentStudent =>
      currentIndex < students.length ? students[currentIndex] : null;

  String get currentClassName {
    final s = currentStudent;
    if (s == null) return '';
    return classNameMap[s.classId] ?? '';
  }

  int get totalCount => students.length;
  int get processedCount => currentIndex;
  bool get hasNext => currentIndex < students.length - 1;

  RollCallState copyWith({
    AttendanceTask? task,
    List<StudentInfo>? students,
    Map<int, String>? classNameMap,
    int? currentIndex,
    bool? isLoading,
    bool? isFinished,
    String? error,
  }) {
    return RollCallState(
      task: task ?? this.task,
      students: students ?? this.students,
      classNameMap: classNameMap ?? this.classNameMap,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isFinished: isFinished ?? this.isFinished,
      error: error,
    );
  }
}

/// 点名流程控制器
class RollCallNotifier extends StateNotifier<RollCallState> {
  final AttendanceRepository _attendanceRepo;
  final StudentRepository _studentRepo;

  RollCallNotifier(this._attendanceRepo, this._studentRepo)
      : super(const RollCallState());

  /// 初始化点名：创建任务 + 加载学生（多班级按学号排序）
  Future<void> startRollCall({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
  }) async {
    state = const RollCallState(isLoading: true);

    try {
      final allStudents = <StudentInfo>[];
      final classNameMap = <int, String>{};

      // 按班级顺序加载学生
      final allClasses = await _studentRepo.getClasses();
      for (final classId in classIds) {
        await _studentRepo.ensureStudentsForClass(classId);
        final students = await _studentRepo.getStudentsByClass(classId);
        allStudents.addAll(students); // 已按学号排序

        final classInfo = allClasses.firstWhere((c) => c.id == classId);
        classNameMap[classId] = classInfo.displayName;
      }

      if (allStudents.isEmpty) {
        state = state.copyWith(isLoading: false, error: '所选班级没有学生数据');
        return;
      }

      // 创建任务
      final task = await _attendanceRepo.createTask(
        type: TaskType.rollCall,
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
        students: allStudents,
        classNameMap: classNameMap,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '初始化失败: $e');
    }
  }

  /// 下一位（标记当前学生为已到）
  Future<void> nextStudent() async {
    final student = state.currentStudent;
    final task = state.task;
    if (student == null || task == null) return;

    await _attendanceRepo.createRecord(
      taskId: task.id,
      studentId: student.id,
      classId: student.classId,
      status: AttendanceStatus.present,
    );

    if (state.hasNext) {
      final newIndex = state.currentIndex + 1;
      final updated = await _attendanceRepo.updateTaskStatus(
        task,
        currentStudentIndex: newIndex,
      );
      state = state.copyWith(task: updated, currentIndex: newIndex);
    } else {
      await finishRollCall();
    }
  }

  /// 结束点名
  Future<void> finishRollCall() async {
    final task = state.task;
    if (task == null) return;

    await _attendanceRepo.updateTaskStatus(
      task,
      status: TaskStatus.completed,
      phase: TaskPhase.confirming,
    );

    state = state.copyWith(isFinished: true);
  }
}
