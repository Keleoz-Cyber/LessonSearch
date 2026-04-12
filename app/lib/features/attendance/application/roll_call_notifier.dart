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
  final Map<int, int> calledRecordIds; // studentId -> recordId（已点学生的记录ID）
  final int? finalCount; // 提前结束时记录实际已点人数
  final bool isLoading;
  final bool isFinished;
  final String? error;

  const RollCallState({
    this.task,
    this.students = const [],
    this.classNameMap = const {},
    this.currentIndex = 0,
    this.calledRecordIds = const {},
    this.finalCount,
    this.isLoading = false,
    this.isFinished = false,
    this.error,
  });

  StudentInfo? get currentStudent =>
      currentIndex < students.length ? students[currentIndex] : null;

  /// 上一位学生
  StudentInfo? get prevStudent =>
      currentIndex > 0 ? students[currentIndex - 1] : null;

  /// 上三位学生列表
  List<StudentInfo> get prevThreeStudents {
    final start = currentIndex - 3;
    if (start < 0) {
      return students.sublist(0, currentIndex);
    }
    return students.sublist(start, currentIndex);
  }

  /// 下一位学生
  StudentInfo? get nextStudent =>
      currentIndex < students.length - 1 ? students[currentIndex + 1] : null;

  String get currentClassName {
    final s = currentStudent;
    if (s == null) return '';
    return classNameMap[s.classId] ?? '';
  }

  int get totalCount => students.length;
  int get processedCount => finalCount ?? currentIndex;
  bool get hasNext => currentIndex < students.length - 1;
  bool get hasPrev => currentIndex > 0;

  /// 检查学生是否已点
  bool isCalled(int studentId) => calledRecordIds.containsKey(studentId);

  RollCallState copyWith({
    AttendanceTask? task,
    List<StudentInfo>? students,
    Map<int, String>? classNameMap,
    int? currentIndex,
    Map<int, int>? calledRecordIds,
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
      calledRecordIds: calledRecordIds ?? this.calledRecordIds,
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

      // 加载已有的考勤记录
      final existingRecords = await _attendanceRepo.getRecordsByTask(taskId);
      final calledRecordIds = <int, int>{};
      for (final r in existingRecords) {
        if (r.id != null) {
          calledRecordIds[r.studentId] = r.id!;
        }
      }

      await _studentRepo.ensureStudentsBatch(task.classIds);
      final classMap = await _studentRepo.getClassMap();
      final studentsMap = await _studentRepo.getStudentsByClasses(
        task.classIds,
      );

      final allStudents = <StudentInfo>[];
      final classNameMap = <int, String>{};

      for (final classId in task.classIds) {
        final students = studentsMap[classId] ?? [];
        allStudents.addAll(students);
        final classInfo = classMap[classId];
        if (classInfo != null) {
          classNameMap[classId] = classInfo.displayName;
        }
      }

      final resumeIndex = task.currentStudentIndex;

      state = state.copyWith(
        task: task,
        students: allStudents,
        classNameMap: classNameMap,
        currentIndex: resumeIndex < allStudents.length ? resumeIndex : 0,
        calledRecordIds: calledRecordIds,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
    }
  }

  /// 初始化点名
  Future<void> startRollCall({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
    int? userId,
  }) async {
    state = const RollCallState(isLoading: true);

    try {
      await _studentRepo.ensureStudentsBatch(classIds);
      final classMap = await _studentRepo.getClassMap();
      final studentsMap = await _studentRepo.getStudentsByClasses(classIds);

      final allStudents = <StudentInfo>[];
      final classNameMap = <int, String>{};

      for (final classId in classIds) {
        final students = studentsMap[classId] ?? [];
        allStudents.addAll(students);
        final classInfo = classMap[classId];
        if (classInfo != null) {
          classNameMap[classId] = classInfo.displayName;
        }
      }

      if (allStudents.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '所选班级没有学生数据，请检查网络连接后重试',
        );
        return;
      }

      final task = await _attendanceRepo.createTask(
        type: TaskType.rollCall,
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
        students: allStudents,
        classNameMap: classNameMap,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
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
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return '请先登录后再使用';
    }
    if (msg.contains('返回空数据')) {
      return '服务器返回空数据，请联系管理员';
    }
    return '加载失败: $msg';
  }

  /// 下一位（记录当前学生为已点）
  Future<void> nextStudent() async {
    final student = state.currentStudent;
    final task = state.task;
    if (student == null || task == null) return;

    // 创建考勤记录并存储 recordId
    final record = await _attendanceRepo.createRecord(
      taskId: task.id,
      studentId: student.id,
      classId: student.classId,
      status: AttendanceStatus.present,
    );

    final newCalledRecordIds = Map<int, int>.from(state.calledRecordIds);
    if (record.id != null) {
      newCalledRecordIds[student.id] = record.id!;
    }

    if (state.hasNext) {
      final newIndex = state.currentIndex + 1;
      final updated = await _attendanceRepo.updateTaskStatus(
        task,
        currentStudentIndex: newIndex,
      );
      state = state.copyWith(
        task: updated,
        currentIndex: newIndex,
        calledRecordIds: newCalledRecordIds,
      );
    } else {
      // 最后一个学生，已点人数 = currentIndex + 1
      state = state.copyWith(
        finalCount: state.currentIndex + 1,
        calledRecordIds: newCalledRecordIds,
      );
      await finishRollCall();
    }
  }

  /// 上一位（撤销当前学生的点名记录，回退界面）
  Future<void> prevStudent() async {
    if (!state.hasPrev) return;

    final student = state.currentStudent;
    final task = state.task;
    if (student == null || task == null) return;

    // 删除当前学生的考勤记录
    final recordId = state.calledRecordIds[student.id];
    if (recordId != null) {
      await _attendanceRepo.deleteRecord(recordId);
    }

    // 回退索引
    final newIndex = state.currentIndex - 1;
    final newCalledRecordIds = Map<int, int>.from(state.calledRecordIds);
    newCalledRecordIds.remove(student.id);

    final updated = await _attendanceRepo.updateTaskStatus(
      task,
      currentStudentIndex: newIndex,
    );

    state = state.copyWith(
      task: updated,
      currentIndex: newIndex,
      calledRecordIds: newCalledRecordIds,
    );
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

    await _attendanceRepo.updateTaskStatus(task, status: TaskStatus.abandoned);

    state = const RollCallState();
  }
}
