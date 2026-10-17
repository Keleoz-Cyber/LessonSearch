"""In-memory-only API fixtures. Never load deployment config or connect to MySQL."""
import sys
import types
from datetime import datetime, timedelta

from sqlalchemy import create_engine, event, MetaData
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import StaticPool

# unittest imports all modules during discovery. Install inert dependencies
# before importing main/models, so even an accidentally missing override cannot
# open the configured production database.
if "app.core.database" not in sys.modules:
    database = types.ModuleType("app.core.database")
    database.Base = declarative_base()
    database.SessionLocal = lambda: (_ for _ in ()).throw(RuntimeError("No live database in tests"))
    database.get_db = lambda: (_ for _ in ()).throw(RuntimeError("Test database override missing"))
    database.engine = None
    sys.modules[database.__name__] = database
if "app.core.config" not in sys.modules:
    config = types.ModuleType("app.core.config")
    for key, value in {"JWT_SECRET": "isolated-regression-test-secret-key", "JWT_EXPIRE_HOURS": 720,
        "SMTP_HOST": "disabled", "SMTP_PORT": 465, "SMTP_USER": "", "SMTP_PASSWORD": "",
        "SMTP_FROM_NAME": "tests"}.items():
        setattr(config, key, value)
    sys.modules[config.__name__] = config

from app.core.database import Base, get_db
from app.models import User, Grade, Major, Class, Student, AttendanceTask, TaskClass, AttendanceRecord, WeekConfig
from routers.auth import _create_token
from main import app
from fastapi.testclient import TestClient


def memory_engine():
    engine = create_engine("sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False})
    @event.listens_for(engine, "connect")
    def foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")
    return engine


class Fixture:
    def __init__(self):
        self.engine = memory_engine()
        # MySQL index names are per-table; SQLite names are global. Clone only
        # the DDL metadata, leaving production model names untouched.
        metadata = MetaData()
        for table in Base.metadata.sorted_tables:
            cloned = table.to_metadata(metadata)
            for index in cloned.indexes:
                index.name = f"{cloned.name}_{index.name}"
        metadata.create_all(self.engine)
        self.sessions = sessionmaker(bind=self.engine)
        self.db = self.sessions()
        def override():
            with self.sessions() as session:
                yield session
        app.dependency_overrides[get_db] = override
        self.client = TestClient(app)
        self.now = datetime.now().replace(microsecond=0)
        self.start = self.now.date() - timedelta(days=self.now.weekday() + 21)
        self.db.add_all([User(id=1, email="member@example.com", role="member"),
            User(id=2, email="admin@example.com", role="admin"),
            User(id=3, email="other@example.com", role="member"),
            Grade(id=1, name="Test", year=2026), Major(id=1, name="Test", short_name="T"),
            WeekConfig(id=1, start_date=self.start - timedelta(weeks=24), semester_name="old", is_active=False),
            WeekConfig(id=2, start_date=self.start, semester_name="current", is_active=True)])
        self.db.commit()
        self.db.add(Class(id=1, grade_id=1, major_id=1, class_code="01", display_name="Test01")); self.db.commit()
        self.db.add_all([Student(id=1, name="Student One", student_no="001", class_id=1),
                         Student(id=2, name="Student Two", student_no="002", class_id=1)])
        self.db.commit()
        for tid, owner in (("task-1", 1), ("task-2", 1), ("legacy-task", None)):
            task = AttendanceTask(id=tid, user_id=owner, type="name_check", status="completed",
                                  phase="finished", created_at=self.now)
            task.task_classes = [TaskClass(class_id=1, sort_order=0)]
            self.db.add(task)
        self.db.commit()
        self.db.add_all([AttendanceRecord(id=1, task_id="task-1", student_id=1, class_id=1, status="absent", remark="old note"),
            AttendanceRecord(id=2, task_id="task-1", student_id=2, class_id=1, status="present"),
            AttendanceRecord(id=3, task_id="task-2", student_id=1, class_id=1, status="absent"),
            AttendanceRecord(id=4, task_id="task-2", student_id=2, class_id=1, status="present")])
        self.db.commit()

    def headers(self, uid=1):
        return {"Authorization": "Bearer " + _create_token(uid)}

    def close(self):
        self.client.close()
        app.dependency_overrides.clear()
        self.db.close()
        self.engine.dispose()
