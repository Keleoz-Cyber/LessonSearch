"""
周次配置API
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from app.core.database import get_db
from app.models import WeekConfig
from app.schemas.week import CurrentWeekResponse, WeekConfigResponse

router = APIRouter(prefix="/week", tags=["week"])


def get_current_week_config(db: Session) -> WeekConfig | None:
    """获取当前活跃的周次配置"""
    return db.query(WeekConfig).filter(WeekConfig.is_active == True).first()


def calculate_week_number(config: WeekConfig, current_date: datetime) -> int:
    """根据配置计算当前周次"""
    days_diff = (current_date.date() - config.start_date).days
    week_number = (days_diff // 7) + 1
    return max(1, week_number)


@router.get("/current", response_model=CurrentWeekResponse)
async def get_current_week(db: Session = Depends(get_db)):
    """获取当前周次信息"""
    config = get_current_week_config(db)
    
    if not config:
        return CurrentWeekResponse(
            week_number=1,
            start_date=datetime.now().date(),
            end_date=datetime.now().date() + timedelta(days=6),
            semester_name=None
        )
    
    current_date = datetime.now()
    week_number = calculate_week_number(config, current_date)
    
    week_start = config.start_date + timedelta(days=(week_number - 1) * 7)
    week_end = week_start + timedelta(days=6)
    
    return {
        "week_number": week_number,
        "start_date": week_start,
        "end_date": week_end,
        "semester_name": config.semester_name
    }


@router.get("/config", response_model=WeekConfigResponse)
async def get_week_config(db: Session = Depends(get_db)):
    """获取周次配置"""
    config = get_current_week_config(db)
    
    if not config:
        return {
            "id": 0,
            "start_date": datetime.now().date(),
            "semester_name": None,
            "is_active": True,
            "created_at": None
        }
    
    return config