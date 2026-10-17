"""Shared ownership, serialization and submitted-task protection."""
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.models import AttendanceTask, AttendanceRecord, Submission, SubmissionRecord


def owned_task(db: Session, task_id: str, user, *, lock: bool = False) -> AttendanceTask:
    query = db.query(AttendanceTask).filter(AttendanceTask.id == task_id)
    task = (query.with_for_update() if lock else query).first()
    if task is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    # A legacy NULL owner is not evidence that every account owns the task.
    if task.user_id != user.id:
        raise HTTPException(status_code=403, detail="无权访问或修改此任务")
    return task


def task_has_submission(db: Session, task_id: str) -> bool:
    return db.query(SubmissionRecord).join(Submission).join(
        AttendanceRecord, SubmissionRecord.record_id == AttendanceRecord.id,
    ).filter(AttendanceRecord.task_id == task_id,
             Submission.status.in_(["pending", "approved"])).with_for_update().first() is not None


def ensure_task_mutable(db: Session, task: AttendanceTask) -> None:
    if task_has_submission(db, task.id):
        raise HTTPException(status_code=403, detail="任务已提交审核，不能修改或放弃；如需修改请先撤回")


def apply_task_patch(db: Session, task: AttendanceTask, body) -> None:
    changes = {key: getattr(body, key) for key in
               ("status", "phase", "current_class_index", "current_student_index")
               if getattr(body, key) is not None and getattr(task, key) != getattr(body, key)}
    if changes:
        # Legacy/cross-device completion closes only the UI workflow. It must
        # remain possible after submission, without reopening attendance data
        # or letting a mixed payload bypass the ordinary mutation lock.
        completion_metadata_only = task.status == "completed" and changes == {"phase": "finished"}
        if not completion_metadata_only:
            ensure_task_mutable(db, task)
        for key, value in changes.items():
            setattr(task, key, value)
