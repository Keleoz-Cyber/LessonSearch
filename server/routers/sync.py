from fastapi import APIRouter, Depends
from sqlalchemy import func
from database import get_db
from models import Grade, Major, Class, Student

router = APIRouter(tags=["sync"])


@router.get("/sync/version")
def get_sync_version(db=Depends(get_db)):
    """返回各数据表的版本信息，用于客户端判断是否需要更新"""

    grade_count = db.query(func.count(Grade.id)).scalar()
    major_count = db.query(func.count(Major.id)).scalar()
    class_count = db.query(func.count(Class.id)).scalar()

    base_version = f"{grade_count}-{major_count}-{class_count}"

    class_versions = {}
    classes = db.query(Class).all()
    for c in classes:
        student_count = db.query(func.count(Student.id)).filter(
            Student.class_id == c.id
        ).scalar()
        max_id = db.query(func.max(Student.id)).filter(
            Student.class_id == c.id
        ).scalar()
        class_versions[c.id] = f"{student_count}-{max_id or 0}"

    return {
        "base_version": base_version,
        "class_versions": class_versions,
    }