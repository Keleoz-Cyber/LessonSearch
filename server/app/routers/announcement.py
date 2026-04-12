from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import Optional

from app.core.database import get_db
from app.core.security import get_current_user_optional
from app.models import Announcement, User

router = APIRouter(prefix="/announcement", tags=["announcement"])


@router.get("")
async def get_announcement(
    db: Session = Depends(get_db)
):
    """获取最新公告（无需登录）"""
    announcement = db.query(Announcement).filter(
        Announcement.is_active == True
    ).order_by(Announcement.version.desc()).first()

    if not announcement:
        return {"version": 0, "title": "", "content": ""}

    return {
        "version": announcement.version,
        "title": announcement.title,
        "content": announcement.content,
        "updated_at": announcement.updated_at.isoformat() if announcement.updated_at else None
    }


@router.get("/for-user")
async def get_announcement_for_user(
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    """获取针对当前用户角色的公告"""
    user_role = current_user.role if current_user else None

    announcement = db.query(Announcement).filter(
        Announcement.is_active == True,
        or_(Announcement.target_role == "all", Announcement.target_role == user_role)
    ).order_by(Announcement.version.desc()).first()

    if not announcement:
        return {"version": 0, "title": "", "content": ""}

    return {
        "version": announcement.version,
        "title": announcement.title,
        "content": announcement.content,
        "updated_at": announcement.updated_at.isoformat() if announcement.updated_at else None
    }