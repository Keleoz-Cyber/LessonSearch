"""Authoritative semester identity and week boundaries (no startup writes)."""
from datetime import date, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.week import WeekConfig


def resolve_semester(db: Session, semester_id: int | None = None) -> WeekConfig:
    query = db.query(WeekConfig)
    if semester_id is None:
        config = query.filter(WeekConfig.is_active.is_(True)).order_by(WeekConfig.id.desc()).first()
    else:
        config = query.filter(WeekConfig.id == semester_id).first()
    if config is None:
        raise HTTPException(status_code=400 if semester_id is None else 404,
                            detail="请先配置学期" if semester_id is None else "学期不存在")
    return config


def semester_end(db: Session, config: WeekConfig) -> date | None:
    following = db.query(WeekConfig).filter(
        WeekConfig.start_date > config.start_date,
    ).order_by(WeekConfig.start_date, WeekConfig.id).first()
    return following.start_date if following else None


def validate_submission_week(db: Session, config: WeekConfig, week_number: int,
                             today: date | None = None) -> None:
    """Allow catch-up submissions; never allow an unstarted or out-of-term week."""
    if week_number < 1:
        raise HTTPException(status_code=400, detail="周次必须大于零")
    today = today or datetime.now().date()
    try:
        week_start = config.start_date + timedelta(weeks=week_number - 1)
    except OverflowError:
        raise HTTPException(status_code=400, detail="周次超出有效范围")
    end = semester_end(db, config)
    if week_start > today or (end is not None and week_start >= end):
        raise HTTPException(status_code=400, detail="不能提交未来或学期范围外的周次")


def validate_task_semester(db: Session, config: WeekConfig, task) -> None:
    # Server task timestamps identify its term, not its attendance week: offline
    # uploads may be late, so do not require the task to be created in that week.
    end = semester_end(db, config)
    if task.created_at is not None:
        created = task.created_at.date()
        if created < config.start_date or (end is not None and created >= end):
            raise HTTPException(status_code=400, detail="任务不属于所选学期")
