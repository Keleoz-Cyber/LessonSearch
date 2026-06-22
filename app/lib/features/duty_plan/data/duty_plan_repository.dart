import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../domain/duty_plan.dart';

class DutyPlanRepository {
  final AppDatabase _db;

  DutyPlanRepository(this._db);

  Future<List<DutyPlan>> getAll() async {
    final query = _db.select(_db.dutyPlanRows)
      ..orderBy([
        (t) => drift.OrderingTerm.asc(t.classStartAt),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<List<DutyPlan>> getByWeek(int weekNumber) async {
    final query = _db.select(_db.dutyPlanRows)
      ..where((t) => t.weekNumber.equals(weekNumber))
      ..orderBy([
        (t) => drift.OrderingTerm.asc(t.classStartAt),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<List<DutyPlan>> getUpcoming({int limit = 10}) async {
    final now = DateTime.now();
    final query = _db.select(_db.dutyPlanRows)
      ..where((t) => t.classStartAt.isBiggerThanValue(now))
      ..orderBy([
        (t) => drift.OrderingTerm.asc(t.classStartAt),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<DutyPlan?> getById(String id) async {
    final query = _db.select(_db.dutyPlanRows)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> upsert(DutyPlan plan) async {
    await _db.into(_db.dutyPlanRows).insertOnConflictUpdate(
          DutyPlanRowsCompanion.insert(
            id: plan.id,
            weekNumber: plan.weekNumber,
            weekday: plan.weekday,
            period: plan.period,
            classIds: DutyPlan.encodeClassIds(plan.classIds),
            className: drift.Value(plan.className),
            remark: drift.Value(plan.remark),
            notificationId: plan.notificationId,
            reminderEnabled: drift.Value(plan.reminderEnabled),
            classStartAt: plan.classStartAt,
            createdAt: drift.Value(plan.createdAt),
          ),
        );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.dutyPlanRows)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.dutyPlanRows).go();
  }

  DutyPlan _toDomain(DutyPlanRow r) {
    return DutyPlan(
      id: r.id,
      weekNumber: r.weekNumber,
      weekday: r.weekday,
      period: r.period,
      classIds: DutyPlan.decodeClassIds(r.classIds),
      className: r.className,
      remark: r.remark,
      notificationId: r.notificationId,
      reminderEnabled: r.reminderEnabled,
      classStartAt: r.classStartAt,
      createdAt: r.createdAt,
    );
  }
}
