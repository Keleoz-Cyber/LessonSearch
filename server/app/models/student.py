"""
学生相关模型
"""
from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class Grade(Base):
    __tablename__ = "grades"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(20), nullable=False)
    year = Column(Integer, unique=True, nullable=False)

    classes = relationship("Class", back_populates="grade")


class Major(Base):
    __tablename__ = "majors"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    short_name = Column(String(20), unique=True, nullable=False)

    classes = relationship("Class", back_populates="major")


class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    grade_id = Column(Integer, ForeignKey("grades.id"), nullable=False)
    major_id = Column(Integer, ForeignKey("majors.id"), nullable=False)
    class_code = Column(String(20), nullable=False)
    display_name = Column(String(50), nullable=False)

    grade = relationship("Grade", back_populates="classes")
    major = relationship("Major", back_populates="classes")
    students = relationship("Student", back_populates="class_")

    __table_args__ = (
        UniqueConstraint("grade_id", "major_id", "class_code", name="uq_class_grade_major_code"),
    )


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    student_no = Column(String(20), unique=True, nullable=False)
    pinyin = Column(String(100), nullable=True)
    pinyin_abbr = Column(String(20), nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)

    class_ = relationship("Class", back_populates="students")