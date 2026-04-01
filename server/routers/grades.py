from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from models import Grade
from schemas import GradeOut

router = APIRouter(prefix="/grades", tags=["年级"])


@router.get("", response_model=list[GradeOut])
def list_grades(db: Session = Depends(get_db)):
    return db.query(Grade).order_by(Grade.year).all()


@router.get("/{grade_id}", response_model=GradeOut)
def get_grade(grade_id: int, db: Session = Depends(get_db)):
    grade = db.query(Grade).filter(Grade.id == grade_id).first()
    if not grade:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="年级不存在")
    return grade
