"""
周次配置相关Schema
"""
from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime


class WeekConfigResponse(BaseModel):
    id: int
    start_date: date
    semester_name: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CurrentWeekResponse(BaseModel):
    week_number: int
    start_date: date
    end_date: date
    semester_name: Optional[str] = None