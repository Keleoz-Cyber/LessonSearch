from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database import get_db
from models import Student, Class
from schemas import StudentOut, StudentDetail, ClassBrief

router = APIRouter(prefix="/students", tags=["学生"])


@router.get("", response_model=list[StudentOut])
def list_students(
    class_id: int | None = Query(None, description="按班级筛选"),
    keyword: str | None = Query(None, description="按姓名/拼音搜索"),
    db: Session = Depends(get_db),
):
    q = db.query(Student)

    if class_id is not None:
        q = q.filter(Student.class_id == class_id)

    if keyword:
        kw = f"%{keyword}%"
        q = q.filter(
            Student.name.like(kw)
            | Student.pinyin.like(kw)
            | Student.pinyin_abbr.like(kw)
            | Student.student_no.like(kw)
        )

    return q.order_by(Student.id).limit(200).all()


@router.get("/by-class/{class_id}", response_model=list[StudentOut])
def list_students_by_class(class_id: int, db: Session = Depends(get_db)):
    students = (
        db.query(Student)
        .filter(Student.class_id == class_id)
        .order_by(Student.student_no)
        .all()
    )
    return students


@router.get("/{student_id}", response_model=StudentDetail)
def get_student(student_id: int, db: Session = Depends(get_db)):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="学生不存在")

    cls = db.query(Class).filter(Class.id == student.class_id).first()

    return StudentDetail(
        id=student.id,
        name=student.name,
        student_no=student.student_no,
        pinyin=student.pinyin,
        pinyin_abbr=student.pinyin_abbr,
        class_id=student.class_id,
        class_info=ClassBrief(
            id=cls.id,
            class_code=cls.class_code,
            display_name=cls.display_name,
        ),
    )
