"""Build semester-scoped rankings atomically; import never runs the job."""
from datetime import datetime, timedelta
import json
import logging

from sqlalchemy import func

from app.core.database import SessionLocal
from app.models import (AttendanceRecord, Student, Submission, SubmissionRecord,
                        SubmissionSnapshot, Class, RankingCache, RankingSummary, WeekConfig)
from app.services.semesters import resolve_semester

logger = logging.getLogger(__name__)
WEIGHTS = {"absent": 1.0, "leave": 0.5, "late": 0.3, "other": 0.2}
PERIOD_TYPES = ["7d", "30d", "total"]
RANK_TYPES = ["score", "rate", "count"]


def get_period_range(period_type, yesterday):
    """Half-open windows, e.g. seven complete dates ending yesterday."""
    end = datetime.combine(yesterday + timedelta(days=1), datetime.min.time())
    if period_type in ("7d", "30d"):
        return end - timedelta(days=7 if period_type == "7d" else 30), end
    return datetime(1970, 1, 1), end


def get_previous_period_range(period_type, yesterday):
    if period_type == "total":
        return None, None
    start, end = get_period_range(period_type, yesterday)
    return start - (end - start), start


def calculate_class_stats(db, period_start, period_end, rank_type, semester_id=None):
    if period_start is None:
        return {}
    semester = resolve_semester(db, semester_id)
    submissions = db.query(Submission).filter(
        Submission.semester_id == semester.id, Submission.status == "approved",
        Submission.submitted_at >= period_start, Submission.submitted_at < period_end,
    ).all()
    if not submissions:
        return {}
    ids = [s.id for s in submissions]
    snapshots = {snap.submission_id: snap for snap in db.query(SubmissionSnapshot).filter(
        SubmissionSnapshot.semester_id == semester.id,
        SubmissionSnapshot.submission_id.in_(ids)).all()}
    current_rosters = dict(db.query(Student.class_id, func.count(Student.id)).group_by(Student.class_id).all())
    unique_records, expected = {}, {}
    for sub in submissions:
        snapshot = snapshots.get(sub.id)
        data = None
        if snapshot is not None:
            try:
                data = json.loads(snapshot.snapshot_data)
            except (ValueError, TypeError):
                pass
        if isinstance(data, dict) and isinstance(data.get("records"), list):
            records = data["records"]
            roster_counts = data.get("task_class_roster_counts", {})
        else:
            rows = db.query(AttendanceRecord).join(SubmissionRecord,
                SubmissionRecord.record_id == AttendanceRecord.id).filter(
                SubmissionRecord.submission_id == sub.id).all()
            records = [{"task_id": r.task_id, "student_id": r.student_id,
                        "class_id": r.class_id, "status": r.status} for r in rows]
            roster_counts = {}
        for record in records:
            cid, tid, sid = record.get("class_id"), record.get("task_id"), record.get("student_id")
            if cid is None or tid is None or sid is None:
                continue
            unique_records[(tid, sid)] = record
            count = roster_counts.get(tid, {}).get(str(cid))
            expected[(cid, tid)] = int(count) if count is not None else current_rosters.get(cid, 0)
    stats, observed = {}, {}
    for (tid, sid), record in unique_records.items():
        cid = record["class_id"]
        values = stats.setdefault(cid, {"absent": 0, "late": 0, "leave": 0, "other": 0, "present": 0})
        if record["status"] in values:
            values[record["status"]] += 1
        observed[(cid, tid)] = observed.get((cid, tid), 0) + 1
    for cid, values in stats.items():
        # Distinct actual tasks, not submission batches; approved snapshots keep
        # each task's roster size stable across later roster changes.
        values["total_expected"] = sum(max(count, observed.get(key, 0))
            for key, count in expected.items() if key[0] == cid)
        values["score"] = calculate_score(values)
        values["rate"] = calculate_rate(values)
        values["count"] = values["absent"]
    return stats


def calculate_score(stats):
    total = stats["total_expected"]
    return sum(stats[k] * weight for k, weight in WEIGHTS.items()) / total if total else 0.0


def calculate_rate(stats):
    return stats["absent"] / stats["total_expected"] if stats["total_expected"] else 0.0


def sort_and_rank(stats, rank_type):
    items = sorted(stats.items(), key=lambda item: (-item[1][rank_type], item[0]))
    for index, (_, data) in enumerate(items, 1):
        data["rank"] = index
    return items


def save_empty_summary(db, period_type, rank_type, semester_id=None):
    semester = resolve_semester(db, semester_id)
    db.add(RankingSummary(semester_id=semester.id, period_type=period_type,
                         rank_type=rank_type, avg_value=0, total_classes=0))


def save_ranking_cache(db, period_type, rank_type, sorted_stats, prev_sorted, semester_id=None):
    semester = resolve_semester(db, semester_id)
    previous = dict(prev_sorted)
    for cid, data in sorted_stats:
        prev = previous.get(cid)
        trend = "NEW"
        if prev is not None:
            delta = prev["rank"] - data["rank"]
            trend = f"UP{delta}" if delta > 0 else f"DOWN{-delta}" if delta < 0 else "SAME"
        db.add(RankingCache(
            semester_id=semester.id, period_type=period_type, rank_type=rank_type,
            class_id=cid, rank_position=data["rank"], rank_value=data[rank_type],
            trend_value=(data[rank_type] - prev[rank_type]) if prev and period_type != "total" else None,
            trend_rank=trend if period_type != "total" else None,
            total_expected=data["total_expected"], total_absent=data["absent"],
            total_late=data["late"], total_leave=data["leave"], total_other=data["other"],
        ))


def save_ranking_summary(db, period_type, rank_type, sorted_stats, prev_stats, semester_id=None):
    if not sorted_stats:
        return save_empty_summary(db, period_type, rank_type, semester_id)
    semester = resolve_semester(db, semester_id)
    avg = sum(data[rank_type] for _, data in sorted_stats) / len(sorted_stats)
    top_cid, top = sorted_stats[0]
    cls = db.query(Class).filter(Class.id == top_cid).first()
    prev_avg = sum(v[rank_type] for v in prev_stats.values()) / len(prev_stats) if prev_stats else None
    prev_top = prev_stats.get(top_cid)
    db.add(RankingSummary(
        semester_id=semester.id, period_type=period_type, rank_type=rank_type,
        avg_value=avg, avg_trend=avg - prev_avg if prev_avg is not None else None,
        top_class_id=top_cid, top_class_name=cls.display_name if cls else None,
        top_value=top[rank_type], top_trend=top[rank_type] - prev_top[rank_type] if prev_top else None,
        total_classes=len(sorted_stats),
    ))


def calculate_rankings(semester_id=None):
    db = SessionLocal()
    try:
        semester = resolve_semester(db, semester_id)
        # Serialize writers for the same term; a failed calculation rolls back
        # the deletion too, so the last good cache remains available.
        db.query(WeekConfig).filter(WeekConfig.id == semester.id).with_for_update().one()
        db.query(RankingCache).filter(RankingCache.semester_id == semester.id).delete()
        db.query(RankingSummary).filter(RankingSummary.semester_id == semester.id).delete()
        yesterday = datetime.now().date() - timedelta(days=1)
        for period in PERIOD_TYPES:
            start, end = get_period_range(period, yesterday)
            prev_start, prev_end = get_previous_period_range(period, yesterday)
            for rank in RANK_TYPES:
                stats = calculate_class_stats(db, start, end, rank, semester.id)
                previous = calculate_class_stats(db, prev_start, prev_end, rank, semester.id)
                ordered, prev_ordered = sort_and_rank(stats, rank), sort_and_rank(previous, rank)
                save_ranking_cache(db, period, rank, ordered, prev_ordered, semester.id)
                save_ranking_summary(db, period, rank, ordered, previous, semester.id)
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("排行榜计算失败，保留原缓存")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    calculate_rankings()
