from fastapi import APIRouter, Depends, HTTPException, Query, Header
from sqlalchemy.orm import Session
from typing import Optional

from database import get_db
from models import AttendanceTask, TaskClass, AttendanceRecord
from schemas import TaskCreate, TaskUpdate, TaskOut
from routers.auth import get_current_user, _verify_token
from models import User

router = APIRouter(prefix="/tasks", tags=["任务"])


def _get_user_id_from_token(authorization: Optional[str]) -> Optional[int]:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    try:
        token = authorization.removeprefix("Bearer ")
        return _verify_token(token)
    except:
        return None


def _task_to_out(task: AttendanceTask, db: Session) -> TaskOut:
    class_ids = [tc.class_id for tc in task.task_classes]
    record_count = db.query(AttendanceRecord).filter(
        AttendanceRecord.task_id == task.id
    ).count()
    return TaskOut(
        id=task.id,
        type=task.type,
        status=task.status,
        phase=task.phase,
        selected_grade_id=task.selected_grade_id,
        selected_major_id=task.selected_major_id,
        current_class_index=task.current_class_index,
        current_student_index=task.current_student_index,
        created_at=task.created_at,
        updated_at=task.updated_at,
        class_ids=class_ids,
        record_count=record_count,
    )


@router.post("", response_model=TaskOut, status_code=201)
def create_task(
    body: TaskCreate,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user_id = _get_user_id_from_token(authorization)

    existing = db.query(AttendanceTask).filter(AttendanceTask.id == body.id).first()
    if existing:
        return _task_to_out(existing, db)

    task = AttendanceTask(
        id=body.id,
        user_id=user_id,
        type=body.type,
        selected_grade_id=body.selected_grade_id,
        selected_major_id=body.selected_major_id,
    )
    db.add(task)
    db.flush()

    for i, cid in enumerate(body.class_ids):
        db.add(TaskClass(task_id=task.id, class_id=cid, sort_order=i))

    db.commit()
    db.refresh(task)
    return _task_to_out(task, db)


@router.get("", response_model=list[TaskOut])
def list_tasks(
    status: str | None = Query(None),
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user_id = _get_user_id_from_token(authorization)

    q = db.query(AttendanceTask)

    if user_id:
        q = q.filter(AttendanceTask.user_id == user_id)
    else:
        q = q.filter(AttendanceTask.user_id == None)

    if status:
        q = q.filter(AttendanceTask.status == status)

    tasks = q.order_by(AttendanceTask.created_at.desc()).limit(50).all()
    return [_task_to_out(t, db) for t in tasks]


@router.get("/{task_id}", response_model=TaskOut)
def get_task(
    task_id: str,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user_id = _get_user_id_from_token(authorization)

    task = db.query(AttendanceTask).filter(AttendanceTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    if user_id and task.user_id != user_id:
        raise HTTPException(status_code=403, detail="无权访问此任务")

    return _task_to_out(task, db)


@router.put("/{task_id}", response_model=TaskOut)
def update_task(
    task_id: str,
    body: TaskUpdate,
    db: Session = Depends(get_db),
    authorization: Optional[str] = Header(None),
):
    user_id = _get_user_id_from_token(authorization)

    task = db.query(AttendanceTask).filter(AttendanceTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    if user_id and task.user_id != user_id:
        raise HTTPException(status_code=403, detail="无权修改此任务")

    if body.status is not None:
        task.status = body.status
    if body.phase is not None:
        task.phase = body.phase
    if body.current_class_index is not None:
        task.current_class_index = body.current_class_index
    if body.current_student_index is not None:
        task.current_student_index = body.current_student_index

    db.commit()
    db.refresh(task)
    return _task_to_out(task, db)
