from sqlalchemy import (
    Column, Integer, String, ForeignKey, UniqueConstraint, create_engine,
)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker

from config import DATABASE_URL

Base = declarative_base()


class Grade(Base):
    __tablename__ = "grades"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(20), nullable=False)       # "2022级"
    year = Column(Integer, unique=True, nullable=False)  # 2022

    classes = relationship("Class", back_populates="grade")

    def __repr__(self):
        return f"<Grade {self.name}>"


class Major(Base):
    __tablename__ = "majors"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)        # "电子信息工程"
    short_name = Column(String(20), unique=True, nullable=False)  # "电信"

    classes = relationship("Class", back_populates="major")

    def __repr__(self):
        return f"<Major {self.short_name}({self.name})>"


class Class(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    grade_id = Column(Integer, ForeignKey("grades.id"), nullable=False)
    major_id = Column(Integer, ForeignKey("majors.id"), nullable=False)
    class_code = Column(String(20), nullable=False)  # "2201"（年级内+专业内唯一）
    display_name = Column(String(50), nullable=False)  # "电信2201班"

    grade = relationship("Grade", back_populates="classes")
    major = relationship("Major", back_populates="classes")
    students = relationship("Student", back_populates="class_")

    __table_args__ = (
        UniqueConstraint("grade_id", "major_id", "class_code", name="uq_class_grade_major_code"),
    )

    def __repr__(self):
        return f"<Class {self.display_name}>"


class Student(Base):
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), nullable=False)
    student_no = Column(String(20), unique=True, nullable=False)
    pinyin = Column(String(100), nullable=True)
    pinyin_abbr = Column(String(20), nullable=True)
    gender = Column(String(10), nullable=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)

    class_ = relationship("Class", back_populates="students")

    __table_args__ = (
        UniqueConstraint("student_no", name="uq_student_no"),
    )

    def __repr__(self):
        return f"<Student {self.name}({self.student_no})>"


# Engine & Session factory
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(bind=engine)
