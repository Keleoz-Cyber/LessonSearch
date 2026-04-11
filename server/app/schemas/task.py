from pydantic import BaseModel
from datetime import datetime


class TaskCreate(BaseModel):
    id: str
    user_id: int | None = None
    type: str
    class_ids: list[int]
    selected_grade_id: int | None = None
    selected_major_id: int | None = None


class TaskUpdate(BaseModel):
    status: str | None = None
    phase: str | None = None
    current_class_index: int | None = None
    current_student_index: int | None = None


class TaskOut(BaseModel):
    id: str
    type: str
    status: str
    phase: str
    selected_grade_id: int | None
    selected_major_id: int | None
    current_class_index: int
    current_student_index: int
    created_at: datetime
    updated_at: datetime
    class_ids: list[int]
    record_count: int

    model_config = {"from_attributes": True}