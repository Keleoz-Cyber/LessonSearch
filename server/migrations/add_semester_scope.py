"""Idempotent, explicit semester migration; never imported by application startup.

Back up MySQL first, stop API/ranking writers, deploy the previous snapshot
migration if needed, then run from server/:
    python -m migrations.add_semester_scope          # read-only inventory
    python -m migrations.add_semester_scope --apply --backup /private/backup.sql.gz --confirm-restore-tested

Backfill is deliberately conservative: submission/export timestamps may be
late submissions or re-exports, NOT the dates on which attendance happened.
Consider every retained configuration whose requested week had already begun
at that timestamp and whose week start is inside that configuration's known
term bounds. Assign only when exactly ONE configuration is compatible. Multiple
candidates, including separate configurations sharing a start date, go to the
isolated legacy term; never prefer the newest or active term to break a tie.

A unique retained candidate is still only a heuristic: lost/overwritten config
history cannot be reconstructed from these timestamps. Operators must review
both inferred assignments and the legacy term against external evidence before
publishing historical data. This migration never changes non-NULL assignments,
including operator-reviewed assignments, on subsequent runs. Rebuild rankings
after applying; old aggregate caches are isolated rather than labelled current.
MySQL DDL implicitly commits: take a backup; do not rely on DDL rollback.
"""
import argparse
from datetime import date, datetime, timedelta

from sqlalchemy import inspect, text
from app.services.schema_readiness import summary_unique_indexes

TABLES = ("submissions", "submission_snapshots", "week_exports", "ranking_cache", "ranking_summary")
LEGACY_NAME = "历史数据（待核对学期）"


def scope_summary_uniqueness(conn):
    """Replace the old global period/rank uniqueness without dropping data."""
    columns = {c["name"] for c in inspect(conn).get_columns("ranking_summary")}
    if not {"semester_id", "period_type", "rank_type"} <= columns:
        return  # Minimal legacy fixtures or a separately managed old table.
    indexes = summary_unique_indexes(inspect(conn))
    required = {"semester_id", "period_type", "rank_type"}
    if not any(set(index["column_names"]) == required for index in indexes):
        conn.execute(text("CREATE UNIQUE INDEX uk_semester_period_rank ON ranking_summary (semester_id, period_type, rank_type)"))
    quote = conn.dialect.identifier_preparer.quote
    for index in indexes:
        if set(index["column_names"]) != {"period_type", "rank_type"}:
            continue
        name = index["name"]
        if not name or name.startswith("sqlite_autoindex"):
            raise RuntimeError("An inline SQLite unique constraint requires an explicit table rebuild")
        statement = "DROP INDEX " + quote(name)
        if conn.dialect.name == "mysql":
            statement += " ON ranking_summary"
        conn.execute(text(statement))


def _as_date(value):
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value)[:10]) if value else None


def migrate(engine, *, apply=False):
    inspector = inspect(engine)
    present = [table for table in TABLES if inspector.has_table(table)]
    if not inspector.has_table("week_config") or not inspector.has_table("submissions"):
        raise RuntimeError("Initialize the existing application tables before this migration")
    report = {"tables": present, "applied": apply, "backfilled": {}}
    if not apply:
        report["missing_columns"] = [table for table in present
            if "semester_id" not in {c["name"] for c in inspector.get_columns(table)}]
        return report

    with engine.begin() as conn:
        dialect = conn.dialect.name
        for table in present:
            columns = {column["name"] for column in inspect(conn).get_columns(table)}
            if "semester_id" not in columns:
                suffix = " REFERENCES week_config(id)" if dialect == "sqlite" else ""
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN semester_id INTEGER NULL{suffix}"))
        configs = list(conn.execute(text("SELECT id, start_date, semester_name FROM week_config ORDER BY start_date, id")).mappings())
        known = [row for row in configs if row["semester_name"] != LEGACY_NAME]
        legacy = next((row["id"] for row in configs if row["semester_name"] == LEGACY_NAME), None)

        def legacy_id():
            nonlocal legacy
            if legacy is None:
                inserted = conn.execute(text("INSERT INTO week_config (start_date, semester_name, is_active) VALUES (:start, :name, :active)"),
                    {"start": "1970-01-05", "name": LEGACY_NAME, "active": False})
                legacy = inserted.lastrowid
            return legacy

        def infer(timestamp, week):
            try:
                when = _as_date(timestamp)
            except (TypeError, ValueError):
                return legacy_id()
            if when is None or week is None or week < 1:
                return legacy_id()
            candidates = []
            for config in known:
                start = _as_date(config["start_date"])
                following_starts = [_as_date(row["start_date"]) for row in known
                                    if _as_date(row["start_date"]) > start]
                end = min(following_starts) if following_starts else None
                try:
                    week_start = start + timedelta(weeks=week - 1)
                except OverflowError:
                    continue
                if week_start <= when and (end is None or week_start < end):
                    # Do not discard an older term merely because the upload or
                    # export happened after another term began. Duplicate start
                    # dates remain separate candidates, never collapsed by date.
                    candidates.append(config["id"])
            return candidates[0] if len(candidates) == 1 else legacy_id()

        for table, timestamp in (("submissions", "submitted_at"), ("week_exports", "exported_at")):
            if table not in present:
                continue
            rows = conn.execute(text(f"SELECT id, week_number, {timestamp} AS happened FROM {table} WHERE semester_id IS NULL")).mappings().all()
            for row in rows:
                conn.execute(text(f"UPDATE {table} SET semester_id=:semester WHERE id=:id"),
                    {"id": row["id"], "semester": infer(row["happened"], row["week_number"])})
            report["backfilled"][table] = len(rows)
        if "submission_snapshots" in present:
            rows = conn.execute(text("SELECT ss.id, s.semester_id FROM submission_snapshots ss LEFT JOIN submissions s ON s.id=ss.submission_id WHERE ss.semester_id IS NULL")).mappings().all()
            for row in rows:
                conn.execute(text("UPDATE submission_snapshots SET semester_id=:semester WHERE id=:id"),
                    {"id": row["id"], "semester": row["semester_id"] or legacy_id()})
            report["backfilled"]["submission_snapshots"] = len(rows)
        for table in ("ranking_cache", "ranking_summary"):
            if table in present:
                count = conn.execute(text(f"SELECT COUNT(*) FROM {table} WHERE semester_id IS NULL")).scalar_one()
                if count:
                    conn.execute(text(f"UPDATE {table} SET semester_id=:semester WHERE semester_id IS NULL"), {"semester": legacy_id()})
                report["backfilled"][table] = count
        for table in present:
            index_name = f"ix_{table}_semester_id"
            if index_name not in {index["name"] for index in inspect(conn).get_indexes(table)}:
                conn.execute(text(f"CREATE INDEX {index_name} ON {table} (semester_id)"))
            if dialect == "mysql":
                conn.execute(text(f"ALTER TABLE {table} MODIFY COLUMN semester_id INTEGER NOT NULL"))
                foreign_keys = inspect(conn).get_foreign_keys(table)
                if not any(fk["constrained_columns"] == ["semester_id"] for fk in foreign_keys):
                    conn.execute(text(f"ALTER TABLE {table} ADD CONSTRAINT fk_{table}_semester FOREIGN KEY (semester_id) REFERENCES week_config(id)"))
        if "ranking_summary" in present:
            scope_summary_uniqueness(conn)
        report["legacy_semester_id"] = legacy
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Explicitly apply schema and data changes")
    parser.add_argument("--backup", type=str, help="Existing private .sql.gz backup, at most 24 hours old")
    parser.add_argument("--confirm-restore-tested", action="store_true",
                        help="Operator confirms successful restore into an isolated database")
    args = parser.parse_args()
    if args.apply:
        if not args.backup or not args.confirm_restore_tested:
            parser.error("--apply requires --backup and --confirm-restore-tested; inventory is the default")
        from pathlib import Path
        from deploy.preflight import check_backup_file
        backup = check_backup_file(Path(args.backup))
        if not backup["ok"]:
            parser.error("Backup metadata check failed: " + backup["reason"])
    # Deliberately deferred: importing migration helpers never loads live config.
    from app.core.database import engine
    print(migrate(engine, apply=args.apply))


if __name__ == "__main__":
    main()
