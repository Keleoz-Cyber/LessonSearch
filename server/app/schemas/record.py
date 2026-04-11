from pydantic import BaseModel
from datetime import datetime


class RecordCreate(BaseModel):
    student_id: int
    class_id: int
    status: str = "pending"
    remark: str | None = None


class RecordUpdate(BaseModel):
    status: str
    remark: str | None = None


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