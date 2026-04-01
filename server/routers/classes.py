from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload

from database import get_db
from models import Class, Student
from schemas import ClassOut, ClassBrief

router = APIRouter(prefix="/classes", tags=["班级"])


@router.get("", response_model=list[ClassOut])
def list_classes(
    grade_id: int | None = Query(None, description="按年级筛选"),
    major_id: int | None = Query(None, description="按专业筛选"),
    db: Session = Depends(get_db),
):
    q = db.query(Class).options(joinedload(Class.grade), joinedload(Class.major))

    if grade_id is not None:
        q = q.filter(Class.grade_id == grade_id)
    if major_id is not None:
        q = q.filter(Class.major_id == major_id)

    classes = q.order_by(Class.class_code).all()

    result = []
    for cls in classes:
        count = db.query(Student).filter(Student.class_id == cls.id).count()
        result.append(ClassOut(
            id=cls.id,
            class_code=cls.class_code,
            display_name=cls.display_name,
            grade=cls.grade,
            major=cls.major,
            student_count=count,
        ))
    return result


@router.get("/{class_id}", response_model=ClassOut)
def get_class(class_id: int, db: Session = Depends(get_db)):
    cls = (
        db.query(Class)
        .options(joinedload(Class.grade), joinedload(Class.major))
        .filter(Class.id == class_id)
        .first()
    )
    if not cls:
        raise HTTPException(status_code=404, detail="班级不存在")

    count = db.query(Student).filter(Student.class_id == cls.id).count()
    return ClassOut(
        id=cls.id,
        class_code=cls.class_code,
        display_name=cls.display_name,
        grade=cls.grade,
        major=cls.major,
        student_count=count,
    )
