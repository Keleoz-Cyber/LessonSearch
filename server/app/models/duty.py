"""
查课职务分配模型
"""
from sqlalchemy import Column, Integer, Boolean, DateTime, ForeignKey, func, UniqueConstraint

from app.core.database import Base


class DutyAssignment(Base):
    __tablename__ = "duty_assignments"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    assigned_by = Column(Integer, ForeignKey("users.id"), nullable=False)  # 分配人（管理员）
    assigned_at = Column(DateTime, server_default=func.now())
    is_active = Column(Boolean, default=True)  # 是否在职
    deactivated_at = Column(DateTime, nullable=True)  # 离职时间

    __table_args__ = (
        UniqueConstraint("user_id", name="uk_user"),  # 每人只能有一条职务记录
    )