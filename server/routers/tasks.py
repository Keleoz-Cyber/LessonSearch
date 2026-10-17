from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import AttendanceTask, TaskClass, AttendanceRecord, User, Class
from app.schemas import TaskCreate, TaskUpdate, TaskOut
from app.services.task_access import owned_task, apply_task_patch

router = APIRouter(prefix="/tasks", tags=["任务"])


def _task_to_out(task: AttendanceTask, db: Session) -> TaskOut:
    class_ids = [tc.class_id for tc in sorted(task.task_classes, key=lambda tc: tc.sort_order)]
    classes = {c.id: c for c in db.query(Class).filter(Class.id.in_(class_ids)).all()}
    return TaskOut(
        id=task.id, type=task.type, status=task.status, phase=task.phase,
        selected_grade_id=task.selected_grade_id, selected_major_id=task.selected_major_id,
        current_class_index=task.current_class_index, current_student_index=task.current_student_index,
        created_at=task.created_at, updated_at=task.updated_at, class_ids=class_ids,
        class_names=[classes[cid].display_name for cid in class_ids if cid in classes],
        record_count=db.query(AttendanceRecord).filter(AttendanceRecord.task_id == task.id).count(),
    )


def _update_existing(db: Session, body: TaskCreate, current_user: User) -> TaskOut:
    existing = owned_task(db, body.id, current_user, lock=True)
    if existing.type != body.type or [tc.class_id for tc in sorted(existing.task_classes, key=lambda tc: tc.sort_order)] != body.class_ids:
        raise HTTPException(status_code=409, detail="任务ID已存在，但任务类型或班级不同")
    apply_task_patch(db, existing, body)
    db.commit()
    db.refresh(existing)
    return _task_to_out(existing, db)


@router.post("", response_model=TaskOut, status_code=201)
def create_task(body: TaskCreate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    if body.user_id is not None and body.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="不能创建其他用户的任务")
    if db.query(AttendanceTask.id).filter(AttendanceTask.id == body.id).first():
        return _update_existing(db, body, current_user)
    if db.query(Class.id).filter(Class.id.in_(body.class_ids)).count() != len(body.class_ids):
        raise HTTPException(status_code=400, detail="班级不存在或重复")
    task = AttendanceTask(
        id=body.id, user_id=current_user.id, type=body.type,
        status=body.status or "in_progress", phase=body.phase or "selecting",
        selected_grade_id=body.selected_grade_id, selected_major_id=body.selected_major_id,
        current_class_index=body.current_class_index or 0,
        current_student_index=body.current_student_index or 0,
    )
    task.task_classes = [TaskClass(class_id=cid, sort_order=i) for i, cid in enumerate(body.class_ids)]
    db.add(task)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if db.query(AttendanceTask.id).filter(AttendanceTask.id == body.id).first():
            return _update_existing(db, body, current_user)
        raise
    db.refresh(task)
    return _task_to_out(task, db)


@router.get("", response_model=list[TaskOut])
def list_tasks(status: str | None = Query(None), db: Session = Depends(get_db),
               current_user: User = Depends(get_current_user)):
    query = db.query(AttendanceTask).filter(AttendanceTask.user_id == current_user.id)
    if status:
        query = query.filter(AttendanceTask.status == status)
    return [_task_to_out(t, db) for t in query.order_by(AttendanceTask.created_at.desc()).limit(50).all()]


@router.get("/{task_id}", response_model=TaskOut)
def get_task(task_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _task_to_out(owned_task(db, task_id, current_user), db)


@router.put("/{task_id}", response_model=TaskOut)
def update_task(task_id: str, body: TaskUpdate, db: Session = Depends(get_db),
                current_user: User = Depends(get_current_user)):
    task = owned_task(db, task_id, current_user, lock=True)
    apply_task_patch(db, task, body)
    db.commit()
    db.refresh(task)
    return _task_to_out(task, db)
