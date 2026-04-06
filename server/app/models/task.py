from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, func
from sqlalchemy.orm import relationship
from app.core.database import Base


class AttendanceTask(Base):
    __tablename__ = "attendance_tasks"

    id = Column(String(36), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    type = Column(String(20), nullable=False)
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