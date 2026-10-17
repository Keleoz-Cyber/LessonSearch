"""
周次配置相关Schema
"""
from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import date, datetime


class WeekConfigResponse(BaseModel):
    id: int
    semester_id: Optional[int] = None
    start_date: date
    semester_name: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CurrentWeekResponse(BaseModel):
    semester_id: Optional[int] = None
    week_number: int
    start_date: date
    end_date: date
    semester_name: Optional[str] = None


class UpdateWeekConfigRequest(BaseModel):
    start_date: date
    semester_name: Optional[str] = None

    @field_validator("start_date")
    @classmethod
    def must_start_on_monday(cls, value: date) -> date:
        if value.weekday() != 0:
            raise ValueError("学期起始日期必须是周一")
        return value
