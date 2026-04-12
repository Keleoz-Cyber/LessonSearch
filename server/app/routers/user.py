"""
实名制与管理员API
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User
from app.schemas.user import UpdateRealNameRequest, AdminResponse, UserOut

router = APIRouter(prefix="/user", tags=["user"])


@router.put("/real-name")
async def update_real_name(
    body: UpdateRealNameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新用户真实姓名"""
    real_name = body.real_name.strip()
    
    if not real_name:
        raise HTTPException(status_code=400, detail="姓名不能为空")
    
    if len(real_name) < 2 or len(real_name) > 20:
        raise HTTPException(status_code=400, detail="姓名长度应为2-20个字符")
    
    current_user.real_name = real_name
    db.commit()
    db.refresh(current_user)
    
    return {"message": "姓名已更新", "real_name": current_user.real_name}


@router.get("/me", response_model=UserOut)
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """获取当前用户信息"""
    return {
        "id": current_user.id,
        "email": current_user.email,
        "nickname": current_user.nickname,
        "real_name": current_user.real_name,
        "role": current_user.role or "member",
        "is_new_user": False
    }


@router.get("/admins", response_model=List[AdminResponse])
async def get_admins(db: Session = Depends(get_db)):
    """获取所有管理员列表"""
    admins = db.query(User).filter(User.role == "admin").all()
    
    return [
        {
            "id": admin.id,
            "email": admin.email,
            "real_name": admin.real_name,
            "nickname": admin.nickname
        }
        for admin in admins
    ]