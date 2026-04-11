"""
周次配置相关模型
"""
from sqlalchemy import Column, Integer, String, Date, DateTime, Boolean, ForeignKey, func, Index

from app.core.database import Base


class WeekConfig(Base):
    __tablename__ = "week_config"

    id = Column(Integer, primary_key=True, autoincrement=True)
    start_date = Column(Date, nullable=False)  # 第1周起始日期（必须是周一）
    semester_name = Column(String(50), nullable=True)  # 学期名称
    is_active = Column(Boolean, default=True)  # 当前活跃学期
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class WeekExport(Base):
    __tablename__ = "week_exports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    week_number = Column(Integer, nullable=False)
    exported_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    exported_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index("idx_week", "week_number"),
    )