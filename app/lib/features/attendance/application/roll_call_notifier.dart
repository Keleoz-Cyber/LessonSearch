import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../data/attendance_repository.dart';
import '../../student/data/student_repository.dart';

/// 点名流程状态
class RollCallState {
  final AttendanceTask? task;
  final List<StudentInfo> students;
  final Map<int, String> classNameMap;
  final int currentIndex;
  final int? finalCount; // 提前结束时记录实际已点人数
  final bool isLoading;
  final bool isFinished;
  final String? error;

  const RollCallState({
    this.task,
    this.students = const [],
    this.classNameMap = const {},
    this.currentIndex = 0,
    this.finalCount,
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
  int get processedCount => finalCount ?? currentIndex;
  bool get hasNext => currentIndex < students.length - 1;

  RollCallState copyWith({
    AttendanceTask? task,
    List<StudentInfo>? students,
    Map<int, String>? classNameMap,
    int? currentIndex,
    int? finalCount,
    bool? isLoading,
    bool? isFinished,
    String? error,
  }) {
    return RollCallState(
      task: task ?? this.task,
      students: students ?? this.students,
      classNameMap: classNameMap ?? this.classNameMap,
      currentIndex: currentIndex ?? this.currentIndex,
      finalCount: finalCount ?? this.finalCount,
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

  /// 恢复未完成的点名任务
  Future<void> resumeTask(String taskId) async {
    state = const RollCallState(isLoading: true);

    try {
      final task = await _attendanceRepo.getTask(taskId);
      if (task == null) {
        state = state.copyWith(isLoading: false, error: '任务不存在');
        return;
      }

      final allStudents = <StudentInfo>[];
      final classNameMap = <int, String>{};
      final allClasses = await _studentRepo.getClasses();

      for (final classId in task.classIds) {
        await _studentRepo.ensureStudentsForClass(classId);
        final students = await _studentRepo.getStudentsByClass(classId);
        allStudents.addAll(students);
        final classInfo = allClasses.firstWhere((c) => c.id == classId);
        classNameMap[classId] = classInfo.displayName;
      }

      // 从上次的位置继续
      final resumeIndex = task.currentStudentIndex;

      state = state.copyWith(
        task: task,
        students: allStudents,
        classNameMap: classNameMap,
        currentIndex: resumeIndex < allStudents.length ? resumeIndex : 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '恢复失败: $e');
    }
  }

  /// 初始化点名
  Future<void> startRollCall({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
  }) async {
    state = const RollCallState(isLoading: true);

    try {
      final allStudents = <StudentInfo>[];
      final classNameMap = <int, String>{};

      final allClasses = await _studentRepo.getClasses();
      for (final classId in classIds) {
        await _studentRepo.ensureStudentsForClass(classId);
        final students = await _studentRepo.getStudentsByClass(classId);
        allStudents.addAll(students);

        final classInfo = allClasses.firstWhere((c) => c.id == classId);
        classNameMap[classId] = classInfo.displayName;
      }

      if (allStudents.isEmpty) {
        state = state.copyWith(isLoading: false, error: '所选班级没有学生数据');
        return;
      }

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

  /// 下一位（记录当前学生为已点）
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
      // 最后一个学生，已点人数 = currentIndex + 1
      state = state.copyWith(finalCount: state.currentIndex + 1);
      await finishRollCall();
    }
  }

  /// 保存当前进度（保存退出时调用）
  Future<void> saveProgress() async {
    final task = state.task;
    if (task == null) return;
    await _attendanceRepo.updateTaskStatus(
      task,
      currentStudentIndex: state.currentIndex,
    );
  }

  /// 结束点名（提前结束时记录实际已点人数）
  Future<void> finishRollCall() async {
    final task = state.task;
    if (task == null) return;

    // 如果是提前结束（不是通过 nextStudent 最后一个触发的），记录当前已点数
    final count = state.finalCount ?? state.currentIndex;

    await _attendanceRepo.updateTaskStatus(
      task,
      status: TaskStatus.completed,
      phase: TaskPhase.confirming,
    );

    state = state.copyWith(finalCount: count, isFinished: true);
  }

  /// 放弃任务
  Future<void> abandonTask() async {
    final task = state.task;
    if (task == null) return;

    await _attendanceRepo.updateTaskStatus(
      task,
      status: TaskStatus.abandoned,
    );

    state = const RollCallState();
  }
}
