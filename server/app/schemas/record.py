from pydantic import BaseModel, Field
from typing import Literal
from datetime import datetime


AttendanceStatus = Literal["pending", "present", "absent", "late", "leave", "other"]


class RecordCreate(BaseModel):
    student_id: int
    class_id: int
    status: AttendanceStatus = "pending"
    remark: str | None = Field(default=None, max_length=200)


class RecordUpdate(BaseModel):
    status: AttendanceStatus
    remark: str | None = Field(default=None, max_length=200)


class RecordBatchUpdateItem(BaseModel):
    task_id: str
    student_id: int
    status: AttendanceStatus
    remark: str | None = Field(default=None, max_length=200)


class RecordBatchUpdateResult(BaseModel):
    success: list[dict]
    failed: list[dict]


class RecordOut(BaseModel):
    id: int
    task_id: str
    student_id: int
    class_id: int
    status: str
    remark: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
