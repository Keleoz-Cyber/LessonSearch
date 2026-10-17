import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

from tests.support import Fixture, memory_engine
from sqlalchemy import inspect, text
from app.models import (Grade, Major, Class, Student, Submission, SubmissionRecord,
                        SubmissionSnapshot, RankingCache, AttendanceRecord)
from app.core.database import Base
from migrations.add_semester_scope import migrate, LEGACY_NAME


class SemesterMigrationTest(unittest.TestCase):
    def setUp(self):
        self.engine = memory_engine()
        with self.engine.begin() as conn:
            for statement in (
                "CREATE TABLE week_config (id INTEGER PRIMARY KEY AUTOINCREMENT, start_date DATE NOT NULL, semester_name VARCHAR(50), is_active BOOLEAN)",
                "CREATE TABLE submissions (id INTEGER PRIMARY KEY, week_number INTEGER NOT NULL, submitted_at DATETIME)",
                "CREATE TABLE submission_snapshots (id INTEGER PRIMARY KEY, submission_id INTEGER REFERENCES submissions(id))",
                "CREATE TABLE week_exports (id INTEGER PRIMARY KEY, week_number INTEGER, exported_at DATETIME)",
                "CREATE TABLE ranking_cache (id INTEGER PRIMARY KEY)",
                "CREATE TABLE ranking_summary (id INTEGER PRIMARY KEY)",
                "INSERT INTO week_config VALUES (1,'2026-02-02','old',0),(2,'2026-09-07','current',1)",
                "INSERT INTO submissions VALUES (1,1,'2026-02-05'),(2,1,'2026-09-10'),(3,1,'2025-01-01'),(4,-99,'2026-09-10')",
                "INSERT INTO submission_snapshots VALUES (1,1),(2,2),(3,3)",
                "INSERT INTO week_exports VALUES (1,1,'2026-02-06'),(2,1,'2026-09-11')",
                "INSERT INTO ranking_cache VALUES (1)",
                "INSERT INTO ranking_summary VALUES (1)",
            ):
                conn.execute(text(statement))

    def tearDown(self):
        self.engine.dispose()

    def test_inventory_does_not_change_schema(self):
        report = migrate(self.engine)
        self.assertFalse(report["applied"])
        self.assertEqual(len(report["missing_columns"]), 5)
        self.assertNotIn("semester_id", {column["name"] for column in inspect(self.engine).get_columns("submissions")})

    def test_backfill_preserves_data_isolates_unknown_and_is_idempotent(self):
        report = migrate(self.engine, apply=True)
        legacy = report["legacy_semester_id"]
        self.assertNotIn(legacy, (None, 1, 2))
        with self.engine.connect() as conn:
            self.assertEqual(dict(conn.execute(text("SELECT id, semester_id FROM submissions")).all()), {1: 1, 2: legacy, 3: legacy, 4: legacy})
            self.assertEqual(dict(conn.execute(text("SELECT id, semester_id FROM submission_snapshots")).all()), {1: 1, 2: legacy, 3: legacy})
            self.assertEqual(dict(conn.execute(text("SELECT id, semester_id FROM week_exports")).all()), {1: 1, 2: legacy})
            self.assertEqual(conn.execute(text("SELECT semester_id FROM ranking_cache")).scalar_one(), legacy)
            self.assertEqual(conn.execute(text("SELECT is_active FROM week_config WHERE semester_name=:name"), {"name": LEGACY_NAME}).scalar_one(), 0)
        again = migrate(self.engine, apply=True)
        self.assertEqual(sum(again["backfilled"].values()), 0)
        with self.engine.connect() as conn:
            self.assertEqual(conn.execute(text("SELECT COUNT(*) FROM submissions")).scalar_one(), 4)
            self.assertEqual(conn.execute(text("SELECT COUNT(*) FROM week_config")).scalar_one(), 3)

    def test_late_old_semester_submission_is_not_guessed_into_new_semester(self):
        with self.engine.begin() as conn:
            conn.execute(text("INSERT INTO submissions VALUES (5,3,'2026-10-01')"))
            conn.execute(text("INSERT INTO submission_snapshots VALUES (5,5)"))
        report = migrate(self.engine, apply=True)
        legacy = report["legacy_semester_id"]
        with self.engine.connect() as conn:
            # Week 3 of either known term has begun by the upload timestamp.
            self.assertEqual(conn.execute(text("SELECT semester_id FROM submissions WHERE id=5")).scalar_one(), legacy)
            self.assertEqual(conn.execute(text("SELECT semester_id FROM submission_snapshots WHERE id=5")).scalar_one(), legacy)

    def test_reexport_after_new_semester_start_is_not_new_semester_publication(self):
        with self.engine.begin() as conn:
            conn.execute(text("INSERT INTO week_exports VALUES (5,4,'2026-10-12')"))
        report = migrate(self.engine, apply=True)
        with self.engine.connect() as conn:
            self.assertEqual(conn.execute(text("SELECT semester_id FROM week_exports WHERE id=5")).scalar_one(), report["legacy_semester_id"])
            self.assertEqual(conn.execute(text("SELECT COUNT(*) FROM week_exports WHERE semester_id=2")).scalar_one(), 0)

    def test_duplicate_start_configurations_are_ambiguous_even_before_next_term(self):
        with self.engine.begin() as conn:
            conn.execute(text("INSERT INTO week_config VALUES (10,'2026-02-02','duplicate old term',0)"))
        report = migrate(self.engine, apply=True)
        with self.engine.connect() as conn:
            for table in ("submissions", "submission_snapshots", "week_exports"):
                self.assertEqual(conn.execute(text(f"SELECT semester_id FROM {table} WHERE id=1")).scalar_one(), report["legacy_semester_id"])

    def test_unique_old_term_candidate_allows_late_upload_without_using_latest_term(self):
        with self.engine.begin() as conn:
            # Old week 31 began Aug 31; new week 31 has not begun in September.
            conn.execute(text("INSERT INTO submissions VALUES (5,31,'2026-09-10')"))
            conn.execute(text("INSERT INTO week_exports VALUES (5,31,'2026-09-11')"))
        migrate(self.engine, apply=True)
        with self.engine.connect() as conn:
            self.assertEqual(conn.execute(text("SELECT semester_id FROM submissions WHERE id=5")).scalar_one(), 1)
            self.assertEqual(conn.execute(text("SELECT semester_id FROM week_exports WHERE id=5")).scalar_one(), 1)

    def test_week_outside_known_old_term_does_not_form_a_false_unique_candidate(self):
        with self.engine.begin() as conn:
            # Old week 32 begins on the next term's start, so belongs to neither
            # old term week 32 nor new term week 32 as of this timestamp.
            conn.execute(text("INSERT INTO submissions VALUES (5,32,'2026-09-10')"))
        report = migrate(self.engine, apply=True)
        with self.engine.connect() as conn:
            self.assertEqual(conn.execute(text("SELECT semester_id FROM submissions WHERE id=5")).scalar_one(), report["legacy_semester_id"])

    def test_repeat_preserves_existing_and_manually_reviewed_assignments(self):
        first = migrate(self.engine, apply=True)
        with self.engine.begin() as conn:
            # Simulate an operator assigning an ambiguous upload using evidence
            # unavailable to the migration, then a later config-history repair.
            conn.execute(text("UPDATE submissions SET semester_id=2 WHERE id=2"))
            conn.execute(text("UPDATE submission_snapshots SET semester_id=2 WHERE id=2"))
            conn.execute(text("UPDATE week_exports SET semester_id=2 WHERE id=2"))
            conn.execute(text("INSERT INTO week_config VALUES (10,'2026-02-02','recovered duplicate term',0)"))
        repeated = migrate(self.engine, apply=True)
        self.assertEqual(sum(repeated["backfilled"].values()), 0)
        self.assertEqual(repeated["legacy_semester_id"], first["legacy_semester_id"])
        with self.engine.connect() as conn:
            for table in ("submissions", "submission_snapshots", "week_exports"):
                self.assertEqual(conn.execute(text(f"SELECT semester_id FROM {table} WHERE id=1")).scalar_one(), 1)
                self.assertEqual(conn.execute(text(f"SELECT semester_id FROM {table} WHERE id=2")).scalar_one(), 2)

    def test_legacy_ranking_unique_index_is_scoped_and_repeated_migration_is_safe(self):
        with self.engine.begin() as conn:
            conn.execute(text("DROP TABLE ranking_summary"))
            conn.execute(text("CREATE TABLE ranking_summary (id INTEGER PRIMARY KEY, period_type TEXT, rank_type TEXT)"))
            conn.execute(text("CREATE UNIQUE INDEX uk_period_rank ON ranking_summary (period_type, rank_type)"))
            conn.execute(text("INSERT INTO ranking_summary VALUES (1,'total','rate')"))
        report = migrate(self.engine, apply=True)
        with self.engine.begin() as conn:
            conn.execute(text("INSERT INTO ranking_summary (id,period_type,rank_type,semester_id) VALUES (2,'total','rate',2)"))
            self.assertEqual(conn.execute(text("SELECT semester_id FROM ranking_summary WHERE id=1")).scalar_one(), report["legacy_semester_id"])
            indexes = {i["name"] for i in inspect(conn).get_indexes("ranking_summary")}
            self.assertIn("uk_semester_period_rank", indexes)
            self.assertNotIn("uk_period_rank", indexes)
        migrate(self.engine, apply=True)
        with self.engine.connect() as conn:
            self.assertEqual(conn.execute(text("SELECT COUNT(*) FROM ranking_summary")).scalar_one(), 2)


class ImportClearRegressionTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.fx.db.add(Submission(id=1, semester_id=2, user_id=1, week_number=1, status="approved"))
        self.fx.db.commit()
        self.fx.db.add_all([SubmissionRecord(submission_id=1, record_id=1),
            SubmissionSnapshot(submission_id=1, semester_id=2, week_number=1, user_id=1, snapshot_data="{}"),
            RankingCache(semester_id=2, period_type="7d", rank_type="rate", class_id=1, rank_position=1, rank_value=.5)])
        self.fx.db.commit()

    def tearDown(self):
        self.fx.close()

    def importer(self, filename):
        path = Path(__file__).resolve().parents[2] / "scripts" / filename
        module = importlib.util.module_from_spec(importlib.util.spec_from_file_location("isolated_importer", path))
        models = types.ModuleType("models")
        for key, value in dict(Base=Base, engine=self.fx.engine, SessionLocal=self.fx.sessions,
            Grade=Grade, Major=Major, Class=Class, Student=Student).items():
            setattr(models, key, value)
        config = types.ModuleType("config"); config.DATABASE_URL = "sqlite://"
        old_path = list(sys.path)
        try:
            with patch.dict(sys.modules, {"models": models, "config": config}):
                module.__spec__.loader.exec_module(module)
        finally:
            sys.path[:] = old_path
        return module

    @staticmethod
    def frame():
        import pandas as pd
        return pd.DataFrame([{"现在年级": 2024, "年级": 2024, "班级": "计科2401", "学号": "9001",
            "姓名": "新学生", "性别": "男", "专业": "计算机科学与技术", "专业名称": "计算机科学与技术"}])

    def run_import(self, module):
        patches = [patch.object(module.pd, "read_excel", return_value=self.frame())]
        if hasattr(module, "glob"):
            patches.append(patch.object(module.glob, "glob", return_value=["synthetic.xlsx"]))
        with contextlib.ExitStack() as stack:
            for item in patches:
                stack.enter_context(item)
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            module.import_students(commit=True, clear=True)

    def assert_clear_succeeded(self, filename):
        self.run_import(self.importer(filename))
        self.fx.db.expire_all()
        self.assertEqual(self.fx.db.query(SubmissionSnapshot).count(), 0)
        self.assertEqual(self.fx.db.query(Submission).count(), 0)
        self.assertEqual(self.fx.db.query(RankingCache).count(), 0)
        self.assertEqual(self.fx.db.query(AttendanceRecord).count(), 0)
        self.assertEqual([student.student_no for student in self.fx.db.query(Student).all()], ["9001"])

    def test_students_import_clears_snapshot_and_ranking_foreign_keys(self):
        self.assert_clear_succeeded("import_students_2022plus.py")

    def test_gpa_import_clears_snapshot_and_ranking_foreign_keys(self):
        self.assert_clear_succeeded("import_from_gpa.py")

    def assert_failure_rolls_back_clear(self, filename):
        module = self.importer(filename)
        session = self.fx.sessions()
        original_flush = session.flush
        def fail_new_objects(*args, **kwargs):
            if session.new:
                raise RuntimeError("Synthetic replacement import failure")
            return original_flush(*args, **kwargs)
        with patch.object(module, "SessionLocal", return_value=session), patch.object(session, "flush", side_effect=fail_new_objects):
            with self.assertRaisesRegex(RuntimeError, "Synthetic replacement"):
                self.run_import(module)
        self.fx.db.expire_all()
        self.assertEqual(self.fx.db.query(SubmissionSnapshot).count(), 1)
        self.assertEqual(self.fx.db.query(Submission).count(), 1)
        self.assertEqual(self.fx.db.query(RankingCache).count(), 1)
        self.assertEqual(self.fx.db.query(Student).count(), 2)

    def test_students_import_failure_rolls_back_clear(self):
        self.assert_failure_rolls_back_clear("import_students_2022plus.py")

    def test_gpa_import_failure_rolls_back_clear(self):
        self.assert_failure_rolls_back_clear("import_from_gpa.py")


if __name__ == "__main__":
    unittest.main()
