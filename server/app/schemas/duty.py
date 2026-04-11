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


class CreateDutyAssignmentRequest(BaseModel):
    user_id: int


class DeactivateDutyRequest(BaseModel):
    pass


class MemberSubmissionStatus(BaseModel):
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    has_duty: bool
    submitted: bool
    submission_count: int = 0
    pending_count: int = 0
    approved_count: int = 0
    rejected_count: int = 0


class WeekSubmissionStatusResponse(BaseModel):
    week_number: int
    total_duty: int
    submitted_count: int
    not_submitted_count: int
    submitted_members: List[MemberSubmissionStatus]
    not_submitted_members: List[MemberSubmissionStatus]