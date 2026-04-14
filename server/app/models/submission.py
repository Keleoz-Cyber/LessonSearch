"""
提交记录相关模型
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, func, Index, UniqueConstraint

from app.core.database import Base


class Submission(Base):
    __tablename__ = "submissions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    week_number = Column(Integer, nullable=False)
    status = Column(String(20), default="pending")  # pending/approved/rejected/cancelled
    reviewer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    review_time = Column(DateTime, nullable=True)
    review_note = Column(Text, nullable=True)
    class_names = Column(String(200), nullable=True)  # 提交时保存班级名称
    submitted_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_user_week", "user_id", "week_number"),
        Index("idx_status", "status"),
        Index("idx_week", "week_number"),
    )


class SubmissionRecord(Base):
    __tablename__ = "submission_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    submission_id = Column(Integer, ForeignKey("submissions.id"), nullable=False)
    record_id = Column(Integer, ForeignKey("attendance_records.id"), nullable=False)

    __table_args__ = (
        UniqueConstraint("record_id", name="uk_record"),  # 一条记录只能属于一个submission
    )