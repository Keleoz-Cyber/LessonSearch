from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from models import AttendanceTask, AttendanceRecord
from schemas import RecordCreate, RecordUpdate, RecordOut

router = APIRouter(prefix="/tasks/{task_id}/records", tags=["考勤记录"])


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


@record_router.put("/{record_id}", response_model=RecordOut)
def update_record(record_id: int, body: RecordUpdate, db: Session = Depends(get_db)):
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")

    record.status = body.status
    db.commit()
    db.refresh(record)
    return record
