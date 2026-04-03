// 查课任务系统领域模型

// ============================================================
// 枚举
// ============================================================

enum TaskType {
  rollCall('roll_call'),
  nameCheck('name_check');

  final String value;
  const TaskType(this.value);

  static TaskType fromString(String s) =>
      TaskType.values.firstWhere((e) => e.value == s);
}

enum TaskStatus {
  inProgress('in_progress'),
  confirming('confirming'),
  textGen('text_gen'),
  completed('completed'),
  abandoned('abandoned');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String s) =>
      TaskStatus.values.firstWhere((e) => e.value == s);
}

enum TaskPhase {
  selecting('selecting'),
  executing('executing'),
  confirming('confirming'),
  textGenerating('text_generating');

  final String value;
  const TaskPhase(this.value);

  static TaskPhase fromString(String s) =>
      TaskPhase.values.firstWhere((e) => e.value == s);
}

enum AttendanceStatus {
  pending('pending'),
  present('present'),
  absent('absent'),
  leave('leave'),
  other('other');

  final String value;
  const AttendanceStatus(this.value);

  static AttendanceStatus fromString(String s) =>
      AttendanceStatus.values.firstWhere((e) => e.value == s);
}

enum SyncStatus {
  pending('pending'),
  synced('synced'),
  failed('failed');

  final String value;
  const SyncStatus(this.value);

  static SyncStatus fromString(String s) =>
      SyncStatus.values.firstWhere((e) => e.value == s);
}

// ============================================================
// 领域模型
// ============================================================

class AttendanceTask {
  final String id;
  final TaskType type;
  final TaskStatus status;
  final TaskPhase phase;
  final int? selectedGradeId;
  final int? selectedMajorId;
  final List<int> classIds;
  final int currentClassIndex;
  final int currentStudentIndex;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceTask({
    required this.id,
    required this.type,
    this.status = TaskStatus.inProgress,
    this.phase = TaskPhase.selecting,
    this.selectedGradeId,
    this.selectedMajorId,
    this.classIds = const [],
    this.currentClassIndex = 0,
    this.currentStudentIndex = 0,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  AttendanceTask copyWith({
    TaskStatus? status,
    TaskPhase? phase,
    int? selectedGradeId,
    int? selectedMajorId,
    List<int>? classIds,
    int? currentClassIndex,
    int? currentStudentIndex,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
  }) {
    return AttendanceTask(
      id: id,
      type: type,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      selectedGradeId: selectedGradeId ?? this.selectedGradeId,
      selectedMajorId: selectedMajorId ?? this.selectedMajorId,
      classIds: classIds ?? this.classIds,
      currentClassIndex: currentClassIndex ?? this.currentClassIndex,
      currentStudentIndex: currentStudentIndex ?? this.currentStudentIndex,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AttendanceRecord {
  final int? id;
  final String taskId;
  final int studentId;
  final int classId;
  final AttendanceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceRecord({
    this.id,
    required this.taskId,
    required this.studentId,
    required this.classId,
    this.status = AttendanceStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  AttendanceRecord copyWith({
    int? id,
    AttendanceStatus? status,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      taskId: taskId,
      studentId: studentId,
      classId: classId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudentInfo {
  final int id;
  final String name;
  final String studentNo;
  final String? pinyin;
  final String? pinyinAbbr;
  final int classId;

  const StudentInfo({
    required this.id,
    required this.name,
    required this.studentNo,
    this.pinyin,
    this.pinyinAbbr,
    required this.classId,
  });
}

class ClassInfo {
  final int id;
  final int gradeId;
  final int majorId;
  final String classCode;
  final String displayName;

  const ClassInfo({
    required this.id,
    required this.gradeId,
    required this.majorId,
    required this.classCode,
    required this.displayName,
  });
}

class GradeInfo {
  final int id;
  final String name;
  final int year;

  const GradeInfo({required this.id, required this.name, required this.year});
}

class MajorInfo {
  final int id;
  final String name;
  final String shortName;

  const MajorInfo({required this.id, required this.name, required this.shortName});
}
