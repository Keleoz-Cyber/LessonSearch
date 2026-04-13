"""
数据版本配置API
用于通知App刷新基础数据
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, Boolean, DateTime
from sqlalchemy.sql import func

from app.core.database import Base, get_db

router = APIRouter(prefix="/data-version", tags=["data-version"])


class DataVersion(Base):
    __tablename__ = "data_version"

    id = Column(Integer, primary_key=True, autoincrement=True)
    version = Column(Integer, nullable=False, default=1)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


@router.get("")
async def get_data_version(db: Session = Depends(get_db)):
    """获取当前数据版本号"""
    config = db.query(DataVersion).first()
    if not config:
        config = DataVersion(version=1)
        db.add(config)
        db.commit()
        db.refresh(config)
    
    return {"version": config.version}


@router.put("")
async def update_data_version(db: Session = Depends(get_db)):
    """更新数据版本号（触发App刷新）"""
    config = db.query(DataVersion).first()
    if not config:
        config = DataVersion(version=2)
        db.add(config)
    else:
        config.version += 1
    db.commit()
    db.refresh(config)
    
    return {"version": config.version, "message": "数据版本已更新，App将自动刷新"}