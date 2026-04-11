"""
提交记录相关Schema
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class CreateSubmissionRequest(BaseModel):
    week_number: int
    task_ids: List[str]


class SubmissionResponse(BaseModel):
    id: int
    user_id: int
    week_number: int
    status: str
    reviewer_id: Optional[int] = None
    review_time: Optional[datetime] = None
    review_note: Optional[str] = None
    submitted_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SubmissionDetailResponse(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    user_email: Optional[str] = None
    week_number: int
    status: str
    reviewer_id: Optional[int] = None
    reviewer_name: Optional[str] = None
    review_time: Optional[datetime] = None
    review_note: Optional[str] = None
    submitted_at: datetime
    task_count: int = 0
    record_count: int = 0


class ApproveSubmissionRequest(BaseModel):
    note: Optional[str] = None


class RejectSubmissionRequest(BaseModel):
    note: str


class WeekSummaryResponse(BaseModel):
    week_number: int
    total_submissions: int
    pending_count: int
    approved_count: int
    rejected_count: int
    late_count: int
    absent_count: int
    is_published: bool


class ExportStatusResponse(BaseModel):
    week_number: int
    is_published: bool
    exported_at: Optional[datetime] = None
    exported_by_name: Optional[str] = None