"""
职务分配相关Schema
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class DutyAssignmentResponse(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    assigned_by: int
    assigned_by_name: Optional[str] = None
    assigned_at: datetime
    is_active: bool
    deactivated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class DutyAssignmentListResponse(BaseModel):
    total: int
    items: List[DutyAssignmentResponse]