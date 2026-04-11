"""
职务分配API
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, DutyAssignment, Submission
from app.schemas.duty import DutyAssignmentResponse, DutyAssignmentListResponse, CreateDutyAssignmentRequest

router = APIRouter(prefix="/duties", tags=["duties"])


@router.get("/", response_model=DutyAssignmentListResponse)
async def get_duty_assignments(
    is_active: bool = True,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取职务分配列表"""
    query = db.query(DutyAssignment)
    
    if is_active:
        query = query.filter(DutyAssignment.is_active == True)
    
    items = query.all()
    
    result = []
    for item in items:
        user = db.query(User).filter(User.id == item.user_id).first()
        assigner = db.query(User).filter(User.id == item.assigned_by).first()
        
        result.append(DutyAssignmentResponse(
            id=item.id,
            user_id=item.user_id,
            user_name=user.real_name if user else None,
            user_email=user.email if user else None,
            assigned_by=item.assigned_by,
            assigned_by_name=assigner.real_name if assigner else None,
            assigned_at=item.assigned_at,
            is_active=item.is_active,
            deactivated_at=item.deactivated_at
        ))
    
    return DutyAssignmentListResponse(total=len(result), items=result)


@router.get("/my", response_model=DutyAssignmentResponse)
async def get_my_duty(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取当前用户的职务分配"""
    duty = db.query(DutyAssignment).filter(
        DutyAssignment.user_id == current_user.id,
        DutyAssignment.is_active == True
    ).first()
    
    if not duty:
        raise HTTPException(status_code=404, detail="您没有查课职务")
    
    assigner = db.query(User).filter(User.id == duty.assigned_by).first()
    
    return DutyAssignmentResponse(
        id=duty.id,
        user_id=duty.user_id,
        user_name=current_user.real_name,
        user_email=current_user.email,
        assigned_by=duty.assigned_by,
        assigned_by_name=assigner.real_name if assigner else None,
        assigned_at=duty.assigned_at,
        is_active=duty.is_active,
        deactivated_at=duty.deactivated_at
    )


@router.get("/unsubmitted", response_model=List[DutyAssignmentResponse])
async def get_unsubmitted_users(
    week_number: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取本周未提交的用户列表（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    # 获取所有在职用户
    active_duties = db.query(DutyAssignment).filter(
        DutyAssignment.is_active == True
    ).all()
    
    active_user_ids = [d.user_id for d in active_duties]
    
    # 获取本周已提交的用户
    submitted_user_ids = db.query(Submission.user_id).filter(
        Submission.week_number == week_number,
        Submission.status.in_(["pending", "approved"])
    ).all()
    
    submitted_user_ids = [u[0] for u in submitted_user_ids]
    
    # 未提交的用户
    unsubmitted_ids = [uid for uid in active_user_ids if uid not in submitted_user_ids]
    
    result = []
    for uid in unsubmitted_ids:
        user = db.query(User).filter(User.id == uid).first()
        duty = db.query(DutyAssignment).filter(
            DutyAssignment.user_id == uid,
            DutyAssignment.is_active == True
        ).first()
        
        if user and duty:
            assigner = db.query(User).filter(User.id == duty.assigned_by).first()
            
            result.append(DutyAssignmentResponse(
                id=duty.id,
                user_id=uid,
                user_name=user.real_name,
                user_email=user.email,
                assigned_by=duty.assigned_by,
                assigned_by_name=assigner.real_name if assigner else None,
                assigned_at=duty.assigned_at,
                is_active=duty.is_active,
                deactivated_at=duty.deactivated_at
            ))
    
    return result


@router.post("/", response_model=DutyAssignmentResponse)
async def create_duty_assignment(
    body: CreateDutyAssignmentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """分配查课职务（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    user = db.query(User).filter(User.id == body.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 检查是否已有职务
    existing = db.query(DutyAssignment).filter(
        DutyAssignment.user_id == body.user_id,
        DutyAssignment.is_active == True
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="用户已有查课职务")
    
    duty = DutyAssignment(
        user_id=body.user_id,
        assigned_by=current_user.id,
        is_active=True
    )
    db.add(duty)
    db.commit()
    db.refresh(duty)
    
    return DutyAssignmentResponse(
        id=duty.id,
        user_id=duty.user_id,
        user_name=user.real_name,
        user_email=user.email,
        assigned_by=duty.assigned_by,
        assigned_by_name=current_user.real_name,
        assigned_at=duty.assigned_at,
        is_active=duty.is_active,
        deactivated_at=duty.deactivated_at
    )


@router.delete("/{duty_id}")
async def deactivate_duty_assignment(
    duty_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """取消查课职务（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    duty = db.query(DutyAssignment).filter(DutyAssignment.id == duty_id).first()
    if not duty:
        raise HTTPException(status_code=404, detail="职务分配不存在")
    
    duty.is_active = False
    duty.deactivated_at = datetime.now()
    db.commit()
    
    return {"message": "职务已取消", "duty_id": duty_id}