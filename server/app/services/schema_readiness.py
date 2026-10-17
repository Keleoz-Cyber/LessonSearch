"""Read-only structural checks. Never create tables, backfill rows or migrate."""
from sqlalchemy import inspect

REQUIRED_COLUMNS = {
    "users": {"id", "password_hash"},
    "attendance_tasks": {"id", "user_id", "phase"},
    "week_config": {"id", "start_date", "semester_name", "is_active"},
    "submissions": {"id", "semester_id"},
    "submission_snapshots": {"id", "semester_id", "snapshot_data"},
    "week_exports": {"id", "semester_id"},
    "ranking_cache": {"id", "semester_id"},
    "ranking_summary": {"id", "semester_id"},
}


def summary_unique_indexes(inspector) -> list[dict]:
    indexes = {item["name"]: item for item in inspector.get_unique_constraints("ranking_summary")}
    for item in inspector.get_indexes("ranking_summary"):
        if item.get("unique"):
            indexes[item["name"]] = item
    return list(indexes.values())


def check_schema(connection) -> dict:
    inspector = inspect(connection)
    missing_tables, missing_columns = [], {}
    nullable_scope, missing_foreign_keys = [], []
    ranking_unique_ready = False
    for table, required in REQUIRED_COLUMNS.items():
        if not inspector.has_table(table):
            missing_tables.append(table)
            continue
        columns = inspector.get_columns(table)
        actual = {column["name"] for column in columns}
        absent = sorted(required - actual)
        if absent:
            missing_columns[table] = absent
        if "semester_id" in actual:
            if next(c for c in columns if c["name"] == "semester_id")["nullable"]:
                nullable_scope.append(table)
            keys = inspector.get_foreign_keys(table)
            if not any(key["constrained_columns"] == ["semester_id"] and
                       key["referred_table"] == "week_config" and
                       key["referred_columns"] == ["id"] for key in keys):
                missing_foreign_keys.append(table)
        if table == "ranking_summary" and {"semester_id", "period_type", "rank_type"} <= actual:
            unique_sets = [set(i["column_names"]) for i in summary_unique_indexes(inspector)]
            ranking_unique_ready = ({"semester_id", "period_type", "rank_type"} in unique_sets and
                                    {"period_type", "rank_type"} not in unique_sets)
    return {
        "ready": not any((missing_tables, missing_columns, nullable_scope, missing_foreign_keys)) and ranking_unique_ready,
        "missing_tables": missing_tables,
        "missing_columns": missing_columns,
        "nullable_semester_columns": nullable_scope,
        "missing_semester_foreign_keys": missing_foreign_keys,
        "ranking_summary_unique_scoped": ranking_unique_ready,
    }
