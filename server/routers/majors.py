from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models import Major
from app.schemas import MajorOut

router = APIRouter(prefix="/majors", tags=["专业"])


@router.get("", response_model=list[MajorOut])
def list_majors(db: Session = Depends(get_db)):
    return db.query(Major).order_by(Major.id).all()


@router.get("/{major_id}", response_model=MajorOut)
def get_major(major_id: int, db: Session = Depends(get_db)):
    major = db.query(Major).filter(Major.id == major_id).first()
    if not major:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="专业不存在")
    return major
