from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import AttendanceTask, AttendanceRecord, Submission, SubmissionRecord, User
from app.schemas import RecordCreate, RecordUpdate, RecordOut, RecordBatchUpdateItem, RecordBatchUpdateResult
from routers.auth import get_current_user

router = APIRouter(prefix="/tasks/{task_id}/records", tags=["考勤记录"])


def _check_record_editable(record_id: int, current_user: User, db: Session) -> AttendanceRecord:
    """检查记录是否可编辑（未关联 pending/approved 的 submission）"""
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")
    
    # 检查是否已关联 pending/approved 的 submission
    sr = db.query(SubmissionRecord).join(Submission).filter(
        SubmissionRecord.record_id == record_id,
        Submission.status.in_(["pending", "approved"])
    ).first()
    
    if sr:
        raise HTTPException(
            status_code=403, 
            detail="该记录已提交审核，不可修改。如需修改，请先撤回提交。"
        )
    
    # 检查是否属于自己的任务（或旧版无 user_id 的任务）
    task = db.query(AttendanceTask).filter(AttendanceTask.id == record.task_id).first()
    if task and task.user_id is not None and task.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权修改此记录")
    
    return record


@router.post("", response_model=list[RecordOut], status_code=201)
def create_records(task_id: str, body: list[RecordCreate], db: Session = Depends(get_db)):
    task = db.query(AttendanceTask).filter(AttendanceTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    created = []
    for item in body:
        existing = db.query(AttendanceRecord).filter(
            AttendanceRecord.task_id == task_id,
            AttendanceRecord.student_id == item.student_id,
        ).first()
        if existing:
            created.append(existing)
            continue

        record = AttendanceRecord(
            task_id=task_id,
            student_id=item.student_id,
            class_id=item.class_id,
            status=item.status,
            remark=item.remark,
        )
        db.add(record)
        created.append(record)

    db.commit()
    for r in created:
        db.refresh(r)
    return created


@router.get("", response_model=list[RecordOut])
def list_records(task_id: str, db: Session = Depends(get_db)):
    records = (
        db.query(AttendanceRecord)
        .filter(AttendanceRecord.task_id == task_id)
        .order_by(AttendanceRecord.id)
        .all()
    )
    return records


# 独立路由：按 record id 更新（不依赖 task_id 路径）
record_router = APIRouter(prefix="/records", tags=["考勤记录"])


@record_router.put("/by-task-student", response_model=RecordOut)
def update_record_by_task_student(
    task_id: str,
    student_id: int,
    body: RecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    record = db.query(AttendanceRecord).filter(
        AttendanceRecord.task_id == task_id,
        AttendanceRecord.student_id == student_id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")
    
    # 检查是否可编辑
    _check_record_editable(record.id, current_user, db)

    record.status = body.status
    if body.remark is not None:
        record.remark = body.remark
    db.commit()
    db.refresh(record)
    return record


@record_router.put("/{record_id}", response_model=RecordOut)
def update_record(
    record_id: int, 
    body: RecordUpdate, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 检查是否可编辑
    record = _check_record_editable(record_id, current_user, db)

    record.status = body.status
    if body.remark is not None:
        record.remark = body.remark
    db.commit()
    db.refresh(record)
    return record


@record_router.post("/batch-update", response_model=RecordBatchUpdateResult)
def batch_update_records(
    body: list[RecordBatchUpdateItem],
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """批量更新考勤记录状态。
    
    每个 item 包含 task_id + student_id + status，按顺序处理。
    已关联 pending/approved submission 的记录会被跳过并返回失败。
    """
    success = []
    failed = []
    
    for item in body:
        try:
            record = db.query(AttendanceRecord).filter(
                AttendanceRecord.task_id == item.task_id,
                AttendanceRecord.student_id == item.student_id,
            ).first()
            
            if not record:
                failed.append({
                    "task_id": item.task_id,
                    "student_id": item.student_id,
                    "reason": "记录不存在"
                })
                continue
            
            # 检查是否可编辑（保留现有校验逻辑）
            sr = db.query(SubmissionRecord).join(Submission).filter(
                SubmissionRecord.record_id == record.id,
                Submission.status.in_(["pending", "approved"])
            ).first()
            
            if sr:
                failed.append({
                    "task_id": item.task_id,
                    "student_id": item.student_id,
                    "reason": "该记录已提交审核，不可修改。如需修改，请先撤回提交。"
                })
                continue
            
            # 检查是否属于自己的任务
            task = db.query(AttendanceTask).filter(
                AttendanceTask.id == item.task_id
            ).first()
            if task and task.user_id is not None and task.user_id != current_user.id:
                failed.append({
                    "task_id": item.task_id,
                    "student_id": item.student_id,
                    "reason": "无权修改此记录"
                })
                continue
            
            # 执行更新
            record.status = item.status
            if item.remark is not None:
                record.remark = item.remark
            
            success.append({
                "task_id": item.task_id,
                "student_id": item.student_id,
                "record_id": record.id
            })
            
        except Exception as e:
            failed.append({
                "task_id": item.task_id,
                "student_id": item.student_id,
                "reason": str(e)
            })
    
    db.commit()
    return {"success": success, "failed": failed}
