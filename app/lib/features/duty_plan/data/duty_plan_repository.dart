import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import '../domain/duty_plan.dart';

class DutyPlanRepository {
  final AppDatabase _db;

  DutyPlanRepository(this._db);

  Future<List<DutyPlan>> getAll() async {
    final query = _db.select(_db.dutyPlanRows)
      ..orderBy([(t) => drift.OrderingTerm.asc(t.classStartAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<List<DutyPlan>> getByWeek(int weekNumber) async {
    final query = _db.select(_db.dutyPlanRows)
      ..where((t) => t.weekNumber.equals(weekNumber))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.classStartAt)]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<List<DutyPlan>> getUpcoming({int limit = 10}) async {
    final now = DateTime.now();
    final query = _db.select(_db.dutyPlanRows)
      ..where((t) => t.classStartAt.isBiggerThanValue(now))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.classStartAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<DutyPlan?> getById(String id) async {
    final query = _db.select(_db.dutyPlanRows)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<DutyPlan> upsert(DutyPlan plan) async {
    return _db.transaction(() async {
      final otherIds =
          (await (_db.select(
                _db.dutyPlanRows,
              )..where((row) => row.id.equals(plan.id).not())).get())
              .map((row) => row.notificationId)
              .toSet();
      var notificationId = plan.notificationId;
      while (otherIds.contains(notificationId)) {
        notificationId++;
      }
      final saved = plan.copyWith(
        notificationId: notificationId,
        reminderStatus: plan.reminderStatus,
        reminderError: plan.reminderError,
      );
      await _db
          .into(_db.dutyPlanRows)
          .insertOnConflictUpdate(
            DutyPlanRowsCompanion.insert(
              id: plan.id,
              weekNumber: plan.weekNumber,
              weekday: plan.weekday,
              period: plan.period,
              classIds: DutyPlan.encodeClassIds(plan.classIds),
              className: drift.Value(plan.className),
              classroom: drift.Value(plan.classroom),
              remark: drift.Value(plan.remark),
              notificationId: saved.notificationId,
              reminderEnabled: drift.Value(plan.reminderEnabled),
              reminderStatus: drift.Value(plan.reminderStatus),
              reminderError: drift.Value(plan.reminderError),
              classStartAt: plan.classStartAt,
              createdAt: drift.Value(plan.createdAt),
            ),
          );
      return saved;
    });
  }

  Future<void> setReminderResult(
    String id,
    String status, [
    String? error,
  ]) async {
    await (_db.update(
      _db.dutyPlanRows,
    )..where((row) => row.id.equals(id))).write(
      DutyPlanRowsCompanion(
        reminderStatus: drift.Value(status),
        reminderError: drift.Value(error),
      ),
    );
  }

  Future<List<DutyPlan>> repairNotificationIds() async {
    return _db.transaction(() async {
      final plans = await getAll();
      final used = <int>{};
      final repaired = <DutyPlan>[];
      for (final plan in plans) {
        var id = DutyPlan.notificationIdFor(plan.id);
        while (used.contains(id)) {
          id++;
        }
        used.add(id);
        final updated = plan.copyWith(
          notificationId: id,
          reminderStatus: plan.reminderStatus,
          reminderError: plan.reminderError,
        );
        if (id != plan.notificationId) {
          await (_db.update(_db.dutyPlanRows)
                ..where((row) => row.id.equals(plan.id)))
              .write(DutyPlanRowsCompanion(notificationId: drift.Value(id)));
        }
        repaired.add(updated);
      }
      return repaired;
    });
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
      classroom: r.classroom,
      remark: r.remark,
      notificationId: r.notificationId,
      reminderEnabled: r.reminderEnabled,
      reminderStatus: r.reminderStatus,
      reminderError: r.reminderError,
      classStartAt: r.classStartAt,
      createdAt: r.createdAt,
    );
  }
}
