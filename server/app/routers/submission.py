"""
提交审核API
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, Submission, SubmissionRecord, AttendanceRecord, AttendanceTask
from app.schemas.submission import (
    CreateSubmissionRequest,
    SubmissionResponse,
    SubmissionDetailResponse,
    ApproveSubmissionRequest,
    RejectSubmissionRequest
)
from app.routers.week import get_current_week_config, calculate_week_number

router = APIRouter(prefix="/submissions", tags=["submissions"])


@router.post("/", response_model=SubmissionResponse)
async def create_submission(
    body: CreateSubmissionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建提交"""
    # 验证任务归属
    tasks = db.query(AttendanceTask).filter(
        AttendanceTask.id.in_(body.task_ids)
    ).all()
    
    for task in tasks:
        if task.user_id != current_user.id:
            raise HTTPException(
                status_code=403,
                detail=f"任务 {task.id} 不属于当前用户"
            )
    
    # 获取考勤记录
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.task_id.in_(body.task_ids)
    ).all()
    
    # 检查记录是否已提交
    existing_submission_ids = db.query(SubmissionRecord.record_id).filter(
        SubmissionRecord.record_id.in_([r.id for r in records if r.id])
    ).all()
    
    if existing_submission_ids:
        raise HTTPException(
            status_code=400,
            detail="部分记录已提交，无法重复提交"
        )
    
    # 创建提交
    submission = Submission(
        user_id=current_user.id,
        week_number=body.week_number,
        status="pending"
    )
    db.add(submission)
    db.flush()
    
    # 关联记录
    for record in records:
        if record.id:
            sr = SubmissionRecord(
                submission_id=submission.id,
                record_id=record.id
            )
            db.add(sr)
    
    db.commit()
    db.refresh(submission)
    
    return submission


@router.get("/", response_model=List[SubmissionResponse])
async def get_submissions(
    week_number: int = None,
    status: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取提交列表"""
    query = db.query(Submission).filter(Submission.user_id == current_user.id)
    
    if week_number:
        query = query.filter(Submission.week_number == week_number)
    
    if status:
        query = query.filter(Submission.status == status)
    
    return query.order_by(Submission.submitted_at.desc()).all()


@router.get("/pending", response_model=List[SubmissionDetailResponse])
async def get_pending_submissions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取待审核提交列表（管理员）"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submissions = db.query(Submission).filter(
        Submission.status == "pending"
    ).all()
    
    result = []
    for sub in submissions:
        user = db.query(User).filter(User.id == sub.user_id).first()
        
        # 统计任务和记录数
        submission_records = db.query(SubmissionRecord).filter(
            SubmissionRecord.submission_id == sub.id
        ).all()
        record_count = len(submission_records)
        task_ids = set()
        for sr in submission_records:
            record = db.query(AttendanceRecord).filter(AttendanceRecord.id == sr.record_id).first()
            if record:
                task_ids.add(record.task_id)
        
        result.append(SubmissionDetailResponse(
            id=sub.id,
            user_id=sub.user_id,
            user_name=user.real_name if user else None,
            user_email=user.email if user else None,
            week_number=sub.week_number,
            status=sub.status,
            reviewer_id=sub.reviewer_id,
            reviewer_name=None,
            review_time=sub.review_time,
            review_note=sub.review_note,
            submitted_at=sub.submitted_at,
            task_count=len(task_ids),
            record_count=record_count
        ))
    
    return result


@router.get("/{submission_id}", response_model=SubmissionDetailResponse)
async def get_submission_detail(
    submission_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取提交详情"""
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    # 权限检查：提交人或管理员可查看
    if submission.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="无权查看此提交")
    
    user = db.query(User).filter(User.id == submission.user_id).first()
    reviewer = None
    if submission.reviewer_id:
        reviewer = db.query(User).filter(User.id == submission.reviewer_id).first()
    
    # 统计
    submission_records = db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission.id
    ).all()
    record_count = len(submission_records)
    task_ids = set()
    for sr in submission_records:
        record = db.query(AttendanceRecord).filter(AttendanceRecord.id == sr.record_id).first()
        if record:
            task_ids.add(record.task_id)
    
    return SubmissionDetailResponse(
        id=submission.id,
        user_id=submission.user_id,
        user_name=user.real_name if user else None,
        user_email=user.email if user else None,
        week_number=submission.week_number,
        status=submission.status,
        reviewer_id=submission.reviewer_id,
        reviewer_name=reviewer.real_name if reviewer else None,
        review_time=submission.review_time,
        review_note=submission.review_note,
        submitted_at=submission.submitted_at,
        task_count=len(task_ids),
        record_count=record_count
    )


@router.put("/{submission_id}/approve")
async def approve_submission(
    submission_id: int,
    body: ApproveSubmissionRequest = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """审核通过"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="提交状态不是待审核")
    
    submission.status = "approved"
    submission.reviewer_id = current_user.id
    submission.review_time = datetime.now()
    if body and body.note:
        submission.review_note = body.note
    
    db.commit()
    
    return {"message": "审核通过", "submission_id": submission_id}


@router.put("/{submission_id}/reject")
async def reject_submission(
    submission_id: int,
    body: RejectSubmissionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """审核拒绝"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="需要管理员权限")
    
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="提交状态不是待审核")
    
    submission.status = "rejected"
    submission.reviewer_id = current_user.id
    submission.review_time = datetime.now()
    submission.review_note = body.note
    
    # 删除关联记录，允许重新提交
    db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission_id
    ).delete()
    
    db.commit()
    
    return {"message": "审核拒绝", "submission_id": submission_id}


@router.delete("/{submission_id}")
async def cancel_submission(
    submission_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """撤销提交"""
    submission = db.query(Submission).filter(Submission.id == submission_id).first()
    
    if not submission:
        raise HTTPException(status_code=404, detail="提交不存在")
    
    if submission.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="只能撤销自己的提交")
    
    if submission.status != "pending":
        raise HTTPException(status_code=400, detail="只能撤销待审核的提交")
    
    # 删除关联记录
    db.query(SubmissionRecord).filter(
        SubmissionRecord.submission_id == submission_id
    ).delete()
    
    submission.status = "cancelled"
    db.commit()
    
    return {"message": "提交已撤销", "submission_id": submission_id}