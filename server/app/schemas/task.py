from pydantic import BaseModel, Field
from typing import Literal
from datetime import datetime


class TaskCreate(BaseModel):
    id: str = Field(min_length=1, max_length=36)
    user_id: int | None = None
    type: Literal["roll_call", "name_check"]
    class_ids: list[int] = Field(min_length=1, max_length=100)
    selected_grade_id: int | None = None
    selected_major_id: int | None = None
    status: str | None = None
    phase: str | None = None
    current_class_index: int | None = Field(default=None, ge=0)
    current_student_index: int | None = Field(default=None, ge=0)


class TaskUpdate(BaseModel):
    status: str | None = None
    phase: str | None = None
    current_class_index: int | None = Field(default=None, ge=0)
    current_student_index: int | None = Field(default=None, ge=0)


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
    class_names: list[str] = []
    record_count: int

    model_config = {"from_attributes": True}
