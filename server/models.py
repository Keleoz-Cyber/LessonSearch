from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Text, func, UniqueConstraint, Boolean
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()


# ============================================================
# 用户系统
# ============================================================

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(100), unique=True, nullable=False)
    nickname = Column(String(50), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    last_login_at = Column(DateTime, nullable=True)


class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(100), nullable=False)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())


# ============================================================
# 基础数据表
# ============================================================

class Grade(Base):
    __tablename__ = "grades"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(20), nullable=False)
    year = Column(Integer, unique=True, nullable=False)

    classes = relationship("Class", back_populates="grade")


class Major(Base):
    __tablename__ = "majors"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    short_name = Column(String(20), unique=True, nullable=False)

    classes = relationship("Class", back_populates="major")


class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    grade_id = Column(Integer, ForeignKey("grades.id"), nullable=False)
    major_id = Column(Integer, ForeignKey("majors.id"), nullable=False)
    class_code = Column(String(20), nullable=False)
    display_name = Column(String(50), nullable=False)

    grade = relationship("Grade", back_populates="classes")
    major = relationship("Major", back_populates="classes")
    students = relationship("Student", back_populates="class_")

    __table_args__ = (
        UniqueConstraint("grade_id", "major_id", "class_code", name="uq_class_grade_major_code"),
    )


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    student_no = Column(String(20), unique=True, nullable=False)
    pinyin = Column(String(100), nullable=True)
    pinyin_abbr = Column(String(20), nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)

    class_ = relationship("Class", back_populates="students")


# ============================================================
# 任务系统
# ============================================================

class AttendanceTask(Base):
    __tablename__ = "attendance_tasks"

    id = Column(String(36), primary_key=True)  # UUID from client
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 登录后绑定
    type = Column(String(20), nullable=False)   # roll_call | name_check
    status = Column(String(20), nullable=False, default="in_progress")
    phase = Column(String(20), nullable=False, default="selecting")
    selected_grade_id = Column(Integer, nullable=True)
    selected_major_id = Column(Integer, nullable=True)
    current_class_index = Column(Integer, default=0)
    current_student_index = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User")
    task_classes = relationship("TaskClass", back_populates="task", cascade="all, delete-orphan")
    records = relationship("AttendanceRecord", back_populates="task", cascade="all, delete-orphan")


class TaskClass(Base):
    __tablename__ = "task_classes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(String(36), ForeignKey("attendance_tasks.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    sort_order = Column(Integer, default=0)

    task = relationship("AttendanceTask", back_populates="task_classes")
    class_ = relationship("Class")


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(String(36), ForeignKey("attendance_tasks.id"), nullable=False)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    status = Column(String(20), nullable=False, default="pending")  # pending|present|absent|leave|other
    remark = Column(String(200), nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    task = relationship("AttendanceTask", back_populates="records")
    student = relationship("Student")
    class_ = relationship("Class")
