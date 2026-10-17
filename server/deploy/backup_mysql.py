"""Explicit Docker MySQL logical backup; never called by startup/preflight.

Credentials must already be in a private MySQL client option file INSIDE the
container. No password is accepted on the command line or printed to output.
The operator must separately test a restore into an isolated database.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import uuid


class BackupError(RuntimeError):
    pass


def dump_command(container: str, defaults_file: str, database: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", container):
        raise BackupError("Invalid container name")
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", database):
        raise BackupError("Invalid database name")
    if not defaults_file.startswith("/") or any(c in defaults_file for c in "\r\n\0"):
        raise BackupError("A container-absolute client option file is required")
    return [
        "docker", "exec", container, "mysqldump",
        f"--defaults-extra-file={defaults_file}", "--single-transaction", "--quick",
        "--routines", "--triggers", "--events", "--no-tablespaces",
        "--set-gtid-purged=OFF", "--default-character-set=utf8mb4",
        "--databases", database,
    ]


def create_backup(output: Path, *, container: str, defaults_file: str,
                  database: str = "lesson_search", popen=None) -> dict:
    command = dump_command(container, defaults_file, database)
    output = output.absolute()
    if not output.name.endswith(".sql.gz") or output.exists() or output.is_symlink():
        raise BackupError("Choose a new .sql.gz file; existing files are never replaced")
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if os.name == "posix" and output.parent.stat().st_mode & 0o077:
        raise BackupError("Backup directory must be private (0700)")
    temporary = output.with_name(f".{output.name}.{uuid.uuid4().hex}.partial")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    process = None
    try:
        with os.fdopen(descriptor, "wb") as target:
            process = (popen or subprocess.Popen)(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            count = 0
            with gzip.GzipFile(filename="", fileobj=target, mode="wb", mtime=0) as compressed:
                while chunk := process.stdout.read(1024 * 1024):
                    compressed.write(chunk)
                    count += len(chunk)
            code = process.wait()
            if code != 0 or count == 0:
                raise BackupError("mysqldump failed or produced no SQL; partial backup discarded")
            target.flush()
            os.fsync(target.fileno())
        digest = hashlib.sha256()
        with temporary.open("rb") as source:
            while chunk := source.read(1024 * 1024):
                digest.update(chunk)
        # Hard linking is an atomic no-replace publish on the same filesystem.
        # A competing backup can never be overwritten after the initial check.
        os.link(temporary, output)
        return {"backup_file": str(output), "bytes": output.stat().st_size,
                "sha256": digest.hexdigest(), "restore_verified": False}
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()
                process.wait()
            if process.stdout is not None:
                process.stdout.close()
        temporary.unlink(missing_ok=True)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", default="1Panel-mysql-ErMk")
    parser.add_argument("--defaults-file", required=True, help="Private client option file already INSIDE the container")
    parser.add_argument("--database", default="lesson_search")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        result = create_backup(args.output, container=args.container,
                               defaults_file=args.defaults_file, database=args.database)
        print(json.dumps(result))
        return 0
    except Exception as error:
        # Neither mysqldump stderr nor arbitrary exception details are printed.
        print(json.dumps({"ok": False, "error_type": type(error).__name__,
                          "details": "Backup failed; no restore or migration was attempted"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
