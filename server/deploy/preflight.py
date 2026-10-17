"""Read-only startup preflight. Does not migrate, back up, chmod or restart."""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import stat

from sqlalchemy import text
from app.services.schema_readiness import check_schema


def check_env_file(path: Path) -> dict:
    result = {"path": str(path), "ok": False}
    try:
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or path.is_symlink():
            return {**result, "reason": "regular_non_symlink_file_required"}
        if os.name == "posix" and info.st_mode & 0o037:
            return {**result, "reason": "group_write_or_other_access", "mode": oct(stat.S_IMODE(info.st_mode))}
        if not os.access(path, os.R_OK):
            return {**result, "reason": "not_readable_by_current_service_user"}
        return {**result, "ok": True, "posix_mode_checked": os.name == "posix"}
    except OSError:
        return {**result, "reason": "file_unavailable"}


def check_backup_file(path: Path, *, max_age_hours: float = 24, now: float | None = None) -> dict:
    result = {"path": str(path), "ok": False, "restore_verified": False}
    if not math.isfinite(max_age_hours) or max_age_hours <= 0:
        return {**result, "reason": "positive_max_age_required"}
    try:
        info = path.stat()
        age = (datetime.now(timezone.utc).timestamp() if now is None else now) - info.st_mtime
        if not path.name.endswith(".sql.gz") or not stat.S_ISREG(info.st_mode) or path.is_symlink() or info.st_size <= 0:
            return {**result, "reason": "nonempty_regular_backup_required"}
        if os.name == "posix" and info.st_mode & 0o077:
            return {**result, "reason": "backup_access_too_broad"}
        if age < -300 or age > max_age_hours * 3600:
            return {**result, "reason": "backup_timestamp_outside_window"}
        return {**result, "ok": True, "bytes": info.st_size, "age_hours": round(max(age, 0) / 3600, 2)}
    except OSError:
        return {**result, "reason": "file_unavailable"}


def check_database(engine) -> dict:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            return {"reachable": True, **check_schema(connection)}
    except Exception as error:
        return {"reachable": False, "ready": False, "error_type": type(error).__name__}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", type=Path, help="Optional existing backup: metadata only, not a restore test")
    parser.add_argument("--max-backup-age-hours", type=float, default=24)
    args = parser.parse_args(argv)
    try:
        from app.core.config import ENV_FILE
        from app.core.environment import validate_production
        validate_production({**os.environ, "APP_ENV": "production"})
        environment = check_env_file(ENV_FILE)
        from app.core.database import engine
        database = check_database(engine)
        backup = check_backup_file(args.backup, max_age_hours=args.max_backup_age_hours) if args.backup else {
            "ok": False, "reason": "not_checked", "restore_verified": False,
        }
        ready = environment["ok"] and database["ready"]
        print(json.dumps({"ready_to_start": ready, "environment": environment, "database": database,
                          "backup": backup, "migration_authorized": False}, ensure_ascii=False))
        return 0 if ready and (args.backup is None or backup["ok"]) else 1
    except Exception as error:
        print(json.dumps({"ready_to_start": False, "error_type": type(error).__name__,
                          "details": "Check configuration locally; secret values are never printed"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
