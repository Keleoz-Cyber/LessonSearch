from pydantic import BaseModel


class GradeOut(BaseModel):
    id: int
    name: str
    year: int

    model_config = {"from_attributes": True}


class MajorOut(BaseModel):
    id: int
    name: str
    short_name: str

    model_config = {"from_attributes": True}


class ClassBrief(BaseModel):
    id: int
    class_code: str
    display_name: str

    model_config = {"from_attributes": True}


class ClassOut(BaseModel):
    id: int
    class_code: str
    display_name: str
    grade: GradeOut
    major: MajorOut
    student_count: int

    model_config = {"from_attributes": True}


class StudentOut(BaseModel):
    id: int
    name: str
    student_no: str
    pinyin: str | None
    pinyin_abbr: str | None
    class_id: int

    model_config = {"from_attributes": True}


class StudentDetail(StudentOut):
    class_info: ClassBrief

    model_config = {"from_attributes": True}