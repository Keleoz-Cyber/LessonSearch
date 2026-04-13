import 'dart:async';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../attendance/domain/models.dart';

class StudentRepository {
  final AppDatabase _db;
  final ApiClient _api;
  final SharedPreferences _prefs;

  static const _keyBaseVersion = 'sync_base_version';
  static const _keyClassVersionPrefix = 'sync_class_version_';
  static const _keyDataVersion = 'data_version';

  StudentRepository(this._db, this._api, this._prefs);

  Future<List<String>> getClassNames(List<int> classIds) async {
    final names = <String>[];
    for (final id in classIds) {
      final row = await (_db.select(
        _db.classes,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (row != null) {
        names.add(row.displayName);
      }
    }
    return names;
  }

  Future<void> syncBaseData() async {
    final gradesJson = await _api.getGrades();
    final majorsJson = await _api.getMajors();
    final classesJson = await _api.getClasses();

    await _db.transaction(() async {
      for (final g in gradesJson) {
        await _db
            .into(_db.grades)
            .insertOnConflictUpdate(
              GradesCompanion.insert(
                id: Value(g['id'] as int),
                name: g['name'] as String,
                year: g['year'] as int,
              ),
            );
      }
      for (final m in majorsJson) {
        await _db
            .into(_db.majors)
            .insertOnConflictUpdate(
              MajorsCompanion.insert(
                id: Value(m['id'] as int),
                name: m['name'] as String,
                shortName: m['short_name'] as String,
              ),
            );
      }
      for (final c in classesJson) {
        await _db
            .into(_db.classes)
            .insertOnConflictUpdate(
              ClassesCompanion.insert(
                id: Value(c['id'] as int),
                gradeId: c['grade']['id'] as int,
                majorId: c['major']['id'] as int,
                classCode: c['class_code'] as String,
                displayName: c['display_name'] as String,
              ),
            );
      }
    });
  }

  Future<void> syncStudentsByClass(int classId) async {
    try {
      final studentsJson = await _api.getStudentsByClass(classId);
      await _db.transaction(() async {
        for (final s in studentsJson) {
          await _db
              .into(_db.students)
              .insertOnConflictUpdate(
                StudentsCompanion.insert(
                  id: Value(s['id'] as int),
                  name: s['name'] as String,
                  studentNo: s['student_no'] as String,
                  pinyin: Value(s['pinyin'] as String?),
                  pinyinAbbr: Value(s['pinyin_abbr'] as String?),
                  classId: s['class_id'] as int,
                ),
              );
        }
      });
    } catch (e) {
      throw Exception('syncStudentsByClass($classId) 失败: $e');
    }
  }

  Future<void> syncStudentsBatch(List<int> classIds) async {
    final futures = classIds.map((id) => syncStudentsByClass(id));
    await Future.wait(futures);
  }

  Future<void> ensureBaseData() async {
    await checkDataVersion();
    final count = await (_db.select(_db.grades)).get();
    if (count.isEmpty) {
      await syncBaseData();
    }
  }

  Future<bool> checkDataVersion() async {
    try {
      final serverVersion = await _api.getDataVersion();
      final localVersion = _prefs.getInt(_keyDataVersion) ?? 0;

      if (serverVersion > localVersion) {
        await _clearBaseData();
        await syncBaseData();
        await _prefs.setInt(_keyDataVersion, serverVersion);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearBaseData() async {
    await _db.delete(_db.students).go();
    await _db.delete(_db.classes).go();
    await _db.delete(_db.majors).go();
    await _db.delete(_db.grades).go();
  }

  Future<bool> checkBaseDataUpdate() async {
    try {
      final version = await _api.getSyncVersion();
      final serverBaseVersion = version['base_version'] as String;
      final localBaseVersion = _prefs.getString(_keyBaseVersion) ?? '';

      if (serverBaseVersion != localBaseVersion) {
        await syncBaseData();
        await _prefs.setString(_keyBaseVersion, serverBaseVersion);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Set<int>> checkClassesUpdate(List<int> classIds) async {
    try {
      final version = await _api.getSyncVersion();
      final classVersions = version['class_versions'] as Map<String, dynamic>;

      final needUpdate = <int>{};
      for (final classId in classIds) {
        final serverVersion = classVersions[classId.toString()] as String?;
        final localVersion =
            _prefs.getString('${_keyClassVersionPrefix}$classId') ?? '';

        if (serverVersion != null && serverVersion != localVersion) {
          needUpdate.add(classId);
        }
      }

      if (needUpdate.isNotEmpty) {
        await syncStudentsBatch(needUpdate.toList());
        for (final classId in needUpdate) {
          final serverVersion = classVersions[classId.toString()] as String;
          await _prefs.setString(
            '${_keyClassVersionPrefix}$classId',
            serverVersion,
          );
        }
      }
      return needUpdate;
    } catch (_) {
      return {};
    }
  }

  Future<void> ensureStudentsForClass(int classId) async {
    final count = await (_db.select(
      _db.students,
    )..where((s) => s.classId.equals(classId))).get();
    if (count.isEmpty) {
      await syncStudentsByClass(classId);
      try {
        final version = await _api.getSyncVersion();
        final classVersions = version['class_versions'] as Map<String, dynamic>;
        final serverVersion = classVersions[classId.toString()] as String?;
        if (serverVersion != null) {
          await _prefs.setString(
            '${_keyClassVersionPrefix}$classId',
            serverVersion,
          );
        }
      } catch (_) {}
    }
  }

  Future<void> ensureStudentsBatch(List<int> classIds) async {
    final missing = <int>[];
    for (final classId in classIds) {
      final count = await (_db.select(
        _db.students,
      )..where((s) => s.classId.equals(classId))).get();
      if (count.isEmpty) {
        missing.add(classId);
      }
    }
    if (missing.isNotEmpty) {
      try {
        await syncStudentsBatch(missing);
        try {
          final version = await _api.getSyncVersion();
          final classVersions =
              version['class_versions'] as Map<String, dynamic>;
          for (final classId in missing) {
            final serverVersion = classVersions[classId.toString()] as String?;
            if (serverVersion != null) {
              await _prefs.setString(
                '${_keyClassVersionPrefix}$classId',
                serverVersion,
              );
            }
          }
        } catch (_) {}
      } catch (e) {
        throw Exception('同步学生数据失败: $e');
      }
    }
  }

  Future<List<GradeInfo>> getGrades() async {
    final rows = await (_db.select(
      _db.grades,
    )..orderBy([(g) => OrderingTerm.asc(g.year)])).get();
    return rows
        .map((r) => GradeInfo(id: r.id, name: r.name, year: r.year))
        .toList();
  }

  Future<List<MajorInfo>> getMajors() async {
    final rows = await (_db.select(
      _db.majors,
    )..orderBy([(m) => OrderingTerm.asc(m.id)])).get();
    return rows
        .map((r) => MajorInfo(id: r.id, name: r.name, shortName: r.shortName))
        .toList();
  }

  Future<List<ClassInfo>> getClasses({int? gradeId, int? majorId}) async {
    var q = _db.select(_db.classes);
    if (gradeId != null || majorId != null) {
      q = q
        ..where((c) {
          Expression<bool>? expr;
          if (gradeId != null) {
            expr = c.gradeId.equals(gradeId);
          }
          if (majorId != null) {
            final majorExpr = c.majorId.equals(majorId);
            expr = expr == null ? majorExpr : expr & majorExpr;
          }
          return expr!;
        });
    }
    final rows = await (q..orderBy([(c) => OrderingTerm.asc(c.classCode)]))
        .get();
    return rows
        .map(
          (r) => ClassInfo(
            id: r.id,
            gradeId: r.gradeId,
            majorId: r.majorId,
            classCode: r.classCode,
            displayName: r.displayName,
          ),
        )
        .toList();
  }

  Future<Map<int, ClassInfo>> getClassMap() async {
    final rows = await (_db.select(_db.classes)).get();
    return {
      for (final r in rows)
        r.id: ClassInfo(
          id: r.id,
          gradeId: r.gradeId,
          majorId: r.majorId,
          classCode: r.classCode,
          displayName: r.displayName,
        ),
    };
  }

  Future<List<StudentInfo>> getStudentsByClassLocal(int classId) async {
    final rows =
        await (_db.select(_db.students)
              ..where((s) => s.classId.equals(classId))
              ..orderBy([(s) => OrderingTerm.asc(s.studentNo)]))
            .get();
    return rows
        .map(
          (r) => StudentInfo(
            id: r.id,
            name: r.name,
            studentNo: r.studentNo,
            pinyin: r.pinyin,
            pinyinAbbr: r.pinyinAbbr,
            classId: r.classId,
          ),
        )
        .toList();
  }

  Future<Map<int, List<StudentInfo>>> getStudentsByClasses(
    List<int> classIds,
  ) async {
    final result = <int, List<StudentInfo>>{};
    for (final classId in classIds) {
      result[classId] = await getStudentsByClassLocal(classId);
    }
    return result;
  }

  Future<StudentInfo?> getStudent(int studentId) async {
    final row = await (_db.select(
      _db.students,
    )..where((s) => s.id.equals(studentId))).getSingleOrNull();
    if (row == null) return null;
    return StudentInfo(
      id: row.id,
      name: row.name,
      studentNo: row.studentNo,
      pinyin: row.pinyin,
      pinyinAbbr: row.pinyinAbbr,
      classId: row.classId,
    );
  }
}
