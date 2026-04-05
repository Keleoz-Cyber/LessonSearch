import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Grades,
    Majors,
    Classes,
    Students,
    AttendanceTasks,
    TaskClasses,
    AttendanceRecords,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v2 新增 users 表和 attendanceTasks.userId 列
          // 先尝试创建表（如果不存在）
          try {
            await m.createTable(users);
          } catch (_) {
            // 表已存在，忽略
          }
          // 添加 userId 列（如果不存在）
          try {
            await m.addColumn(attendanceTasks, attendanceTasks.userId);
          } catch (_) {
            // 列已存在，忽略
          }
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lesson_search.db'));
    return NativeDatabase.createInBackground(file);
  });
}
