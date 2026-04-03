import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../data/attendance_repository.dart';
import '../../student/data/student_repository.dart';

/// 点名流程状态
class RollCallState {
  final AttendanceTask? task;
  final List<StudentInfo> students;
  final int currentIndex;
  final bool isLoading;
  final bool isFinished;
  final String? error;

  const RollCallState({
    this.task,
    this.students = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isFinished = false,
    this.error,
  });

  StudentInfo? get currentStudent =>
      currentIndex < students.length ? students[currentIndex] : null;

  int get totalCount => students.length;
  int get processedCount => currentIndex;
  bool get hasNext => currentIndex < students.length - 1;

  RollCallState copyWith({
    AttendanceTask? task,
    List<StudentInfo>? students,
    int? currentIndex,
    bool? isLoading,
    bool? isFinished,
    String? error,
  }) {
    return RollCallState(
      task: task ?? this.task,
      students: students ?? this.students,
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

  /// 初始化点名：创建任务 + 加载学生
  Future<void> startRollCall({
    required int classId,
    required int gradeId,
    required int majorId,
  }) async {
    // 重置所有状态
    state = const RollCallState(isLoading: true);

    try {
      // 确保学生数据已在本地
      await _studentRepo.ensureStudentsForClass(classId);
      final students = await _studentRepo.getStudentsByClass(classId);

      if (students.isEmpty) {
        state = state.copyWith(isLoading: false, error: '该班级没有学生数据');
        return;
      }

      // 打乱顺序（随机点名）
      final shuffled = List<StudentInfo>.from(students)..shuffle();

      // 创建任务
      final task = await _attendanceRepo.createTask(
        type: TaskType.rollCall,
        classIds: [classId],
        selectedGradeId: gradeId,
        selectedMajorId: majorId,
      );

      // 更新任务状态为执行中
      final updated = await _attendanceRepo.updateTaskStatus(
        task,
        phase: TaskPhase.executing,
      );

      state = state.copyWith(
        task: updated,
        students: shuffled,
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

    // 记录当前学生为 present
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
      // 最后一个学生，自动结束
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
