import 'package:drift/drift.dart';

// ============================================================
// 表定义（镜像 MySQL 结构）
// ============================================================

class Grades extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 20)();
  IntColumn get year => integer().unique()();
}

class Majors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get shortName => text().withLength(max: 20).unique()();
}

class Classes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gradeId => integer().references(Grades, #id)();
  IntColumn get majorId => integer().references(Majors, #id)();
  TextColumn get classCode => text().withLength(max: 20)();
  TextColumn get displayName => text().withLength(max: 50)();
}

class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get studentNo => text().withLength(max: 20).unique()();
  TextColumn get pinyin => text().withLength(max: 100).nullable()();
  TextColumn get pinyinAbbr => text().withLength(max: 20).nullable()();
  IntColumn get classId => integer().references(Classes, #id)();
}

// ============================================================
// 任务系统表
// ============================================================

class AttendanceTasks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get type => text()(); // roll_call | name_check
  TextColumn get status => text().withDefault(const Constant('in_progress'))();
  TextColumn get phase => text().withDefault(const Constant('selecting'))();
  IntColumn get selectedGradeId => integer().nullable()();
  IntColumn get selectedMajorId => integer().nullable()();
  IntColumn get currentClassIndex => integer().withDefault(const Constant(0))();
  IntColumn get currentStudentIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // pending|synced|failed

  @override
  Set<Column> get primaryKey => {id};
}

class TaskClasses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().references(AttendanceTasks, #id)();
  IntColumn get classId => integer().references(Classes, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class AttendanceRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().references(AttendanceTasks, #id)();
  IntColumn get studentId => integer().references(Students, #id)();
  IntColumn get classId => integer().references(Classes, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|present|absent|leave|other
  TextColumn get remark => text().nullable()(); // "其他"状态的自定义说明
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payload => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))(); // pending|syncing|synced|failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
