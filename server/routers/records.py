from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models import AttendanceRecord, User, Student
from app.schemas import RecordCreate, RecordUpdate, RecordOut, RecordBatchUpdateItem, RecordBatchUpdateResult
from app.services.task_access import owned_task, ensure_task_mutable

router = APIRouter(prefix="/tasks/{task_id}/records", tags=["考勤记录"])
record_router = APIRouter(prefix="/records", tags=["考勤记录"])


def _validate_student_record_membership(task_class_ids: set[int], student: Student | None,
                                       payload_class_id: int) -> None:
    if student is None:
        raise HTTPException(status_code=400, detail="学生不存在")
    if payload_class_id not in task_class_ids:
        raise HTTPException(status_code=400, detail="班级不属于该任务")
    if student.class_id != payload_class_id:
        raise HTTPException(status_code=400, detail="学生不属于提交的班级")


def _check_record_editable(record_id: int, current_user: User, db: Session) -> AttendanceRecord:
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if record is None:
        raise HTTPException(status_code=404, detail="记录不存在")
    task = owned_task(db, record.task_id, current_user, lock=True)
    if task.status == "abandoned":
        raise HTTPException(status_code=403, detail="该任务已放弃，不可修改记录")
    ensure_task_mutable(db, task)
    return db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).with_for_update().one()


def _record_for_student(db: Session, task_id: str, student_id: int):
    return db.query(AttendanceRecord).filter(AttendanceRecord.task_id == task_id,
        AttendanceRecord.student_id == student_id).order_by(AttendanceRecord.id.desc()).with_for_update().first()


def _apply_record_patch(record, body):
    record.status = body.status
    # Omission means retain; explicit JSON null means clear.
    if "remark" in body.model_fields_set:
        record.remark = body.remark


@router.post("", response_model=list[RecordOut], status_code=201)
def create_records(task_id: str, body: list[RecordCreate], db: Session = Depends(get_db),
                   current_user: User = Depends(get_current_user)):
    task = owned_task(db, task_id, current_user, lock=True)
    result = []
    for item in body:
        student = db.query(Student).filter(Student.id == item.student_id).first()
        _validate_student_record_membership({tc.class_id for tc in task.task_classes}, student, item.class_id)
        record = _record_for_student(db, task_id, item.student_id)
        unchanged = record is not None and record.status == item.status and (
            "remark" not in item.model_fields_set or record.remark == item.remark)
        if not unchanged:
            if task.status == "abandoned":
                raise HTTPException(status_code=403, detail="该任务已放弃，不可修改记录")
            ensure_task_mutable(db, task)
            if record is None:
                record = AttendanceRecord(task_id=task_id, student_id=item.student_id,
                                          class_id=student.class_id, status=item.status)
                db.add(record)
            _apply_record_patch(record, item)
            db.flush()
        result.append(record)
    db.commit()
    return result


@router.get("", response_model=list[RecordOut])
def list_records(task_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owned_task(db, task_id, current_user)
    return db.query(AttendanceRecord).filter(AttendanceRecord.task_id == task_id).order_by(AttendanceRecord.id).all()


@record_router.put("/by-task-student", response_model=RecordOut)
def update_record_by_task_student(task_id: str, student_id: int, body: RecordUpdate,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owned_task(db, task_id, current_user, lock=True)
    record = _record_for_student(db, task_id, student_id)
    if record is None:
        raise HTTPException(status_code=404, detail="记录不存在")
    _check_record_editable(record.id, current_user, db)
    _apply_record_patch(record, body)
    db.commit()
    return record


@record_router.delete("/by-task-student")
def delete_record_by_task_student(task_id: str, student_id: int,
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    task = owned_task(db, task_id, current_user, lock=True)
    records = db.query(AttendanceRecord).filter(AttendanceRecord.task_id == task_id,
        AttendanceRecord.student_id == student_id).with_for_update().all()
    if records:
        if task.status == "abandoned":
            raise HTTPException(status_code=403, detail="该任务已放弃，不可修改记录")
        ensure_task_mutable(db, task)
        for record in records:
            # Cancelled/rejected history does not keep FK links; submitted data
            # is protected above before any physical removal.
            db.delete(record)
        db.commit()
    return {"task_id": task_id, "student_id": student_id, "deleted": bool(records)}


@record_router.post("/batch-update", response_model=RecordBatchUpdateResult)
def batch_update_records(body: list[RecordBatchUpdateItem], db: Session = Depends(get_db),
                         current_user: User = Depends(get_current_user)):
    success, failed = [], []
    for item in sorted(body, key=lambda item: (item.task_id, item.student_id)):
        try:
            with db.begin_nested():
                task = owned_task(db, item.task_id, current_user, lock=True)
                record = _record_for_student(db, item.task_id, item.student_id)
                if record is None:
                    raise HTTPException(status_code=404, detail="记录不存在")
                _validate_student_record_membership({tc.class_id for tc in task.task_classes},
                    db.query(Student).filter(Student.id == item.student_id).first(), record.class_id)
                _check_record_editable(record.id, current_user, db)
                _apply_record_patch(record, item)
                db.flush()
                success.append({"task_id": item.task_id, "student_id": item.student_id, "record_id": record.id})
        except HTTPException as exc:
            failed.append({"task_id": item.task_id, "student_id": item.student_id, "reason": str(exc.detail)})
    db.commit()
    return {"success": success, "failed": failed}


@record_router.put("/{record_id}", response_model=RecordOut)
def update_record(record_id: int, body: RecordUpdate, db: Session = Depends(get_db),
                  current_user: User = Depends(get_current_user)):
    record = _check_record_editable(record_id, current_user, db)
    _apply_record_patch(record, body)
    db.commit()
    return record
