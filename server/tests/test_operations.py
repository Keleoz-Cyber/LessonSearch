"""No deployment config, live database, Docker or SSH is used by these tests."""
import contextlib
import gzip
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

from tests.support import Fixture, memory_engine
from sqlalchemy import event, inspect, text
import main as api
from app.core import environment
from app.services.schema_readiness import check_schema
from app.version import API_VERSION
from deploy import preflight, backup_mysql


class EnvironmentTest(unittest.TestCase):
    def test_server_env_precedes_project_env_and_explicit_path_wins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); server = root / "server"; server.mkdir()
            (root / ".env").touch()
            self.assertEqual(environment.select_env_file(server, {}), root / ".env")
            (server / ".env").touch()
            self.assertEqual(environment.select_env_file(server, {}), server / ".env")
            self.assertEqual(environment.select_env_file(server, {"LESSONSEARCH_ENV_FILE": str(root / "private.env")}), (root / "private.env").resolve())

    @unittest.skipIf(os.name == "nt", "Symlink creation requires elevated privileges on Windows")
    def test_explicit_env_normalizes_symlinked_parent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            real = root / "real"; real.mkdir()
            alias = root / "alias"; alias.symlink_to(real, target_is_directory=True)
            self.assertEqual(environment.select_env_file(root, {"LESSONSEARCH_ENV_FILE": str(alias / "private.env")}), (real / "private.env").resolve())

    def test_raw_password_special_characters_are_not_url_delimiters(self):
        password = "fixture@:/#%+?&password"
        url = environment.database_url({"DB_PASSWORD": password, "DB_USER": "fixture@example"})
        self.assertEqual(url.password, password)
        self.assertEqual(url.username, "fixture@example")
        self.assertNotIn(password, str(url))

    def test_production_rejects_missing_default_short_or_blank_secrets(self):
        for secret in ("", environment.DEFAULT_JWT_SECRET, "short", " " * 40):
            with self.subTest(secret_type=len(secret)), self.assertRaises(ValueError):
                environment.validate_production({"APP_ENV": "production", "JWT_SECRET": secret, "DB_PASSWORD": "fixture"})
        with self.assertRaises(ValueError):
            environment.validate_production({"APP_ENV": "production", "JWT_SECRET": "x" * 40})
        environment.validate_production({"APP_ENV": "production", "JWT_SECRET": "x" * 40, "DB_PASSWORD": "fixture"})

    def test_config_loads_only_injected_fixture_and_preserves_environment_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / ".env"
            fixture.write_text("DB_HOST=file-host\nDB_PASSWORD=fixture-secret\nJWT_SECRET=" + "x" * 40 + "\nAPP_ENV=production\n", encoding="utf-8")
            spec = importlib.util.spec_from_file_location("isolated_config", Path(__file__).parents[1] / "app/core/config.py")
            module = importlib.util.module_from_spec(spec)
            with patch.dict(os.environ, {"DB_HOST": "environment-host"}, clear=True), patch.object(environment, "select_env_file", return_value=fixture):
                spec.loader.exec_module(module)
            self.assertEqual(module.DB_HOST, "environment-host")
            self.assertEqual(module.ENV_FILE, fixture)
            self.assertEqual(module.DATABASE_URL.password, "fixture-secret")


class HealthAndSchemaTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()

    def tearDown(self):
        self.fx.close()

    def sessions(self, fail=False):
        self.closed = False
        def iterator():
            try:
                if fail:
                    raise RuntimeError("fixture-sensitive-connection-string")
                yield self.fx.db
            finally:
                self.closed = True
        return iterator

    def test_liveness_and_openapi_share_version_without_database_access(self):
        with patch.object(api, "get_db", side_effect=AssertionError("No database in liveness")):
            response = self.fx.client.get("/health")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["version"], API_VERSION)
            self.assertIn("semester_scope", response.json()["capabilities"])
            self.assertEqual(self.fx.client.get("/openapi.json").json()["info"]["version"], API_VERSION)

    def test_database_health_closes_generator(self):
        with patch.object(api, "get_db", self.sessions()):
            self.assertEqual(self.fx.client.get("/health/db").json()["database"], "connected")
        self.assertTrue(self.closed)

    def test_database_failure_is_503_without_connection_details_and_closes_generator(self):
        with patch.object(api, "get_db", self.sessions(fail=True)):
            response = self.fx.client.get("/api/health/db")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("fixture-sensitive", response.text)
        self.assertTrue(self.closed)

    def test_upgraded_schema_is_ready(self):
        with patch.object(api, "get_db", self.sessions()):
            self.assertEqual(self.fx.client.get("/api/health/ready").status_code, 200)
        self.assertTrue(self.closed)

    def test_readiness_database_failure_is_sanitized(self):
        with patch.object(api, "get_db", self.sessions(fail=True)):
            response = self.fx.client.get("/health/ready")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("fixture-sensitive", response.text)

    def test_legacy_schema_is_not_ready_and_no_ddl_is_issued(self):
        engine = memory_engine()
        try:
            with engine.begin() as conn:
                conn.execute(text("CREATE TABLE submissions (id INTEGER PRIMARY KEY)"))
            issued = []
            event.listen(engine, "before_cursor_execute", lambda c, cu, statement, p, co, many: issued.append(statement))
            with engine.connect() as conn:
                report = check_schema(conn)
            self.assertFalse(report["ready"])
            self.assertEqual(report["missing_columns"]["submissions"], ["semester_id"])
            self.assertEqual(inspect(engine).get_table_names(), ["submissions"])
            self.assertFalse(any(s.lstrip().upper().startswith(("CREATE ", "ALTER ", "INSERT ", "UPDATE ", "DELETE ")) for s in issued))
            with patch.object(api, "get_db", self.sessions()), patch.object(api, "check_schema", return_value=report):
                response = self.fx.client.get("/health/ready")
            self.assertEqual(response.status_code, 503)
            self.assertEqual(response.json()["schema"], "upgrade_required")
            self.assertNotIn("submissions", response.text)
        finally:
            engine.dispose()

    def test_new_client_routes_are_published(self):
        paths = self.fx.client.get("/openapi.json").json()["paths"]
        self.assertIn("delete", paths["/api/records/by-task-student"])
        self.assertIn("get", paths["/api/week/semesters"])
        self.assertIn("put", paths["/api/records/by-task-student"])

    def test_partially_added_columns_do_not_pass_readiness(self):
        from app.services.schema_readiness import REQUIRED_COLUMNS
        engine = memory_engine()
        try:
            with engine.begin() as connection:
                for table, columns in REQUIRED_COLUMNS.items():
                    definitions = ','.join(f'"{column}" INTEGER' for column in columns)
                    connection.execute(text(f'CREATE TABLE "{table}" ({definitions})'))
                report = check_schema(connection)
            self.assertFalse(report["ready"])
            self.assertEqual(report["missing_tables"], [])
            self.assertEqual(report["missing_columns"], {})
            self.assertEqual(len(report["nullable_semester_columns"]), 5)
            self.assertEqual(len(report["missing_semester_foreign_keys"]), 5)
        finally:
            engine.dispose()

    def test_old_global_ranking_constraint_fails_readiness(self):
        with self.fx.engine.begin() as connection:
            connection.execute(text("CREATE UNIQUE INDEX legacy_global_period_rank ON ranking_summary(period_type,rank_type)"))
            report = check_schema(connection)
        self.assertFalse(report["ready"])
        self.assertFalse(report["ranking_summary_unique_scoped"])

    def test_legacy_put_remains_supported_without_weakening_ownership(self):
        path = "/api/records/by-task-student?task_id=task-1&student_id=1"
        self.assertEqual(self.fx.client.put(path, json={"status": "late"}).status_code, 401)
        self.assertEqual(self.fx.client.put(path, headers=self.fx.headers(3), json={"status": "late"}).status_code, 403)
        response = self.fx.client.put(path, headers=self.fx.headers(), json={"status": "late", "remark": None})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "late")
        self.assertIsNone(response.json()["remark"])


class PreflightTest(unittest.TestCase):
    def test_env_permissions_reject_644_accept_640_and_unreadable_is_rejected(self):
        path = unittest.mock.Mock(spec=Path)
        path.is_symlink.return_value = False
        for mode, expected in ((0o644, False), (0o640, True), (0o600, True), (0o660, False)):
            path.stat.return_value = types.SimpleNamespace(st_mode=stat.S_IFREG | mode)
            with self.subTest(mode=oct(mode)), patch.object(preflight.os, "name", "posix"), patch.object(preflight.os, "access", return_value=True):
                self.assertEqual(preflight.check_env_file(path)["ok"], expected)
        with patch.object(preflight.os, "access", return_value=False):
            self.assertFalse(preflight.check_env_file(path)["ok"])

    def test_backup_metadata_never_claims_restore_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.sql.gz"; path.write_bytes(b"fixture"); path.chmod(0o600)
            now = path.stat().st_mtime
            self.assertTrue(preflight.check_backup_file(path, now=now)["ok"])
            self.assertFalse(preflight.check_backup_file(path, now=now)["restore_verified"])
            self.assertFalse(preflight.check_backup_file(path, now=now + 25 * 3600)["ok"])
            self.assertFalse(preflight.check_backup_file(path, now=now - 600)["ok"])
            self.assertFalse(preflight.check_backup_file(path, max_age_hours=float('nan'))["ok"])
            path.write_bytes(b"")
            self.assertFalse(preflight.check_backup_file(path)["ok"])

    def test_config_file_is_not_a_database_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.py.bak"; path.write_bytes(b"fixture")
            self.assertFalse(preflight.check_backup_file(path)["ok"])

    def test_database_exception_details_are_not_reported(self):
        engine = unittest.mock.Mock()
        engine.connect.side_effect = RuntimeError("fixture-secret")
        result = preflight.check_database(engine)
        self.assertFalse(result["ready"])
        self.assertNotIn("fixture-secret", json.dumps(result))

    def test_cli_is_read_only_and_does_not_claim_backup_or_migration_authority(self):
        fx = Fixture()
        try:
            output = io.StringIO()
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / ".env"; path.touch(); path.chmod(0o600)
                with patch.object(sys.modules["app.core.config"], "ENV_FILE", path, create=True), patch.object(sys.modules["app.core.database"], "engine", fx.engine), patch.dict(os.environ, {"JWT_SECRET": "x" * 40, "DB_PASSWORD": "fixture"}), contextlib.redirect_stdout(output):
                    code = preflight.main([])
            data = json.loads(output.getvalue())
            self.assertEqual(code, 0)
            self.assertTrue(data["ready_to_start"])
            self.assertEqual(data["backup"]["reason"], "not_checked")
            self.assertFalse(data["migration_authorized"])
        finally:
            fx.close()


class BackupToolTest(unittest.TestCase):
    def fake_process(self, data=b"-- isolated fixture\nCREATE TABLE fixture (id INT);\n", code=0):
        process = unittest.mock.Mock()
        process.stdout = io.BytesIO(data)
        process.wait.return_value = code
        process.poll.return_value = code
        return process

    def test_streaming_backup_is_compressed_and_never_overwrites(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "fixture.sql.gz"
            fake = self.fake_process()
            factory = unittest.mock.Mock(return_value=fake)
            result = backup_mysql.create_backup(output, container="fixture-mysql", defaults_file="/run/secrets/fixture.cnf", popen=factory)
            self.assertIn(b"CREATE TABLE fixture", gzip.decompress(output.read_bytes()))
            self.assertEqual(len(result["sha256"]), 64)
            self.assertFalse(result["restore_verified"])
            self.assertEqual(list(Path(directory).glob("*.partial")), [])
            command = factory.call_args.args[0]
            self.assertEqual(command[4], "--defaults-extra-file=/run/secrets/fixture.cnf")
            self.assertIn("--single-transaction", command)
            self.assertFalse(any(s.startswith("--password") for s in command))
            with self.assertRaises(backup_mysql.BackupError):
                backup_mysql.create_backup(output, container="fixture-mysql", defaults_file="/run/secrets/fixture.cnf", popen=factory)
            self.assertEqual(factory.call_count, 1)

    def test_failed_or_empty_dump_has_no_completed_or_partial_file(self):
        for data, code in ((b"partial data", 1), (b"", 0)):
            with self.subTest(code=code), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "fixture.sql.gz"
                with self.assertRaises(backup_mysql.BackupError):
                    backup_mysql.create_backup(output, container="fixture-mysql", defaults_file="/run/secrets/fixture.cnf", popen=lambda *a, **kw: self.fake_process(data, code))
                self.assertEqual(list(Path(directory).iterdir()), [])

    def test_disk_failure_kills_process_and_removes_partial_file(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "fixture.sql.gz"; fake = self.fake_process()
            fake.poll.return_value = None
            with patch.object(backup_mysql.gzip.GzipFile, "write", side_effect=OSError("fixture disk full")):
                with self.assertRaises(OSError):
                    backup_mysql.create_backup(output, container="fixture-mysql", defaults_file="/run/secrets/fixture.cnf", popen=lambda *a, **kw: fake)
            fake.kill.assert_called_once()
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_publish_race_preserves_existing_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "fixture.sql.gz"
            link = os.link
            def competing_link(source, destination):
                output.write_bytes(b"existing backup")
                return link(source, destination)
            with patch.object(backup_mysql.os, "link", side_effect=competing_link), self.assertRaises(FileExistsError):
                backup_mysql.create_backup(output, container="fixture-mysql", defaults_file="/run/secrets/fixture.cnf", popen=lambda *a, **kw: self.fake_process())
            self.assertEqual(output.read_bytes(), b"existing backup")
            self.assertEqual(list(Path(directory).iterdir()), [output])

    def test_backup_cli_suppresses_exception_details(self):
        output = io.StringIO()
        with patch.object(backup_mysql, "create_backup", side_effect=RuntimeError("fixture-sensitive-token")), contextlib.redirect_stdout(output):
            self.assertEqual(backup_mysql.main(["--defaults-file", "/private.cnf", "--output", "unused.sql.gz"]), 1)
        self.assertNotIn("fixture-sensitive-token", output.getvalue())

    def test_service_template_checks_before_start_and_remains_loopback_only(self):
        import configparser
        parser = configparser.ConfigParser(strict=False, interpolation=None)
        parser.read(Path(__file__).parents[1] / "deploy/lesson-search.service", encoding="utf-8")
        service = parser["Service"]
        self.assertIn("deploy.preflight", service["ExecStartPre"])
        self.assertIn("--host 127.0.0.1", service["ExecStart"])
        self.assertEqual(service["User"], "www-data")
        self.assertEqual(service["WorkingDirectory"], "/opt/lesson-search/current/server")
        self.assertEqual(service["ProtectSystem"], "strict")
        self.assertEqual(service["NoNewPrivileges"], "true")
        self.assertEqual(service["Restart"], "always")

    def test_invalid_arguments_never_launch_docker(self):
        for container, database, option in (("--privileged", "lesson_search", "/safe"), ("mysql", "--all-databases", "/safe"), ("mysql", "lesson_search", "relative.cnf")):
            with self.subTest(container=container), self.assertRaises(backup_mysql.BackupError):
                backup_mysql.dump_command(container, option, database)


class MigrationCliGateTest(unittest.TestCase):
    def test_apply_without_backup_confirmation_exits_before_loading_database(self):
        from migrations import add_semester_scope as migration
        for args in (["--apply"], ["--apply", "--backup", "missing.sql.gz"], ["--apply", "--confirm-restore-tested"]):
            with self.subTest(args=args), patch.object(sys, "argv", ["migration", *args]), patch.object(migration, "migrate") as run, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    migration.main()
                self.assertEqual(error.exception.code, 2)
                run.assert_not_called()

    def test_apply_rejects_missing_backup_even_with_operator_confirmation(self):
        from migrations import add_semester_scope as migration
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing.sql.gz"
            with patch.object(sys, "argv", ["migration", "--apply", "--backup", str(path), "--confirm-restore-tested"]), patch.object(migration, "migrate") as run, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    migration.main()
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
