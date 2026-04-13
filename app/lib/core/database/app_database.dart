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
          try {
            await m.createTable(users);
          } catch (_) {}
          try {
            await m.addColumn(attendanceTasks, attendanceTasks.userId);
          } catch (_) {}
        }
      },
    );
  }

  Future<void> clearUserData() async {
    await delete(syncQueue).go();
    await delete(attendanceRecords).go();
    await delete(taskClasses).go();
    await delete(attendanceTasks).go();
    await delete(students).go();
    await delete(classes).go();
    await delete(majors).go();
    await delete(grades).go();
  }

  Future<int> getUnsyncedCount() async {
    var count = 0;
    final queueList = await select(syncQueue).get();
    count += queueList.length;
    final unfinishedQuery = select(attendanceTasks)
      ..where((t) => t.status.equals('unfinished'));
    final unfinishedList = await unfinishedQuery.get();
    count += unfinishedList.length;
    return count;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lesson_search.db'));
    return NativeDatabase.createInBackground(file);
  });
}
