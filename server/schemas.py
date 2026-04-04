from pydantic import BaseModel, EmailStr
from datetime import datetime


# ============================================================
# 用户认证
# ============================================================

class SendCodeRequest(BaseModel):
    email: EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    code: str
    invitation_code: str


class UserOut(BaseModel):
    id: int
    email: str
    nickname: str | None
    is_new_user: bool = False

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    token: str
    user: UserOut


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


# ============================================================
# 任务系统
# ============================================================

class TaskCreate(BaseModel):
    id: str  # client-generated UUID
    user_id: int | None = None  # 登录后的用户 ID
    type: str  # roll_call | name_check
    class_ids: list[int]
    selected_grade_id: int | None = None
    selected_major_id: int | None = None


class TaskUpdate(BaseModel):
    status: str | None = None
    phase: str | None = None
    current_class_index: int | None = None
    current_student_index: int | None = None


class TaskOut(BaseModel):
    id: str
    type: str
    status: str
    phase: str
    selected_grade_id: int | None
    selected_major_id: int | None
    current_class_index: int
    current_student_index: int
    created_at: datetime
    updated_at: datetime
    class_ids: list[int]
    record_count: int

    model_config = {"from_attributes": True}


class RecordCreate(BaseModel):
    student_id: int
    class_id: int
    status: str = "pending"
    remark: str | None = None


class RecordUpdate(BaseModel):
    status: str
    remark: str | None = None


class RecordOut(BaseModel):
    id: int
    task_id: str
    student_id: int
    class_id: int
    status: str
    remark: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
