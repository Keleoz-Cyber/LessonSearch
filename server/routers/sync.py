from fastapi import APIRouter, Depends
from sqlalchemy import func
from app.core.database import get_db
from app.models import Grade, Major, Class, Student

router = APIRouter(tags=["sync"])


@router.get("/sync/version")
def get_sync_version(db=Depends(get_db)):
    """返回各数据表的版本信息，用于客户端判断是否需要更新"""

    grade_count = db.query(func.count(Grade.id)).scalar()
    major_count = db.query(func.count(Major.id)).scalar()
    class_count = db.query(func.count(Class.id)).scalar()

    base_version = f"{grade_count}-{major_count}-{class_count}"

    # 优化：一次 group_by 查询获取所有班级的学生统计
    student_stats = db.query(
        Student.class_id,
        func.count(Student.id).label("cnt"),
        func.max(Student.id).label("max_id"),
    ).group_by(Student.class_id).all()

    stats_map = {row.class_id: (row.cnt, row.max_id or 0) for row in student_stats}

    # 获取所有班级 ID
    class_ids = db.query(Class.id).all()

    class_versions = {}
    for (cid,) in class_ids:
        cnt, max_id = stats_map.get(cid, (0, 0))
        class_versions[cid] = f"{cnt}-{max_id}"

    return {
        "base_version": base_version,
        "class_versions": class_versions,
    }
