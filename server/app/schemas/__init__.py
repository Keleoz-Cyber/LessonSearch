from app.schemas.user import (
    SendCodeRequest,
    LoginRequest,
    RegisterRequest,
    UserOut,
    LoginResponse,
)
from app.schemas.student import (
    GradeOut,
    MajorOut,
    ClassBrief,
    ClassOut,
    StudentOut,
    StudentDetail,
)
from app.schemas.task import TaskCreate, TaskUpdate, TaskOut
from app.schemas.record import RecordCreate, RecordUpdate, RecordOut

__all__ = [
    "SendCodeRequest",
    "LoginRequest",
    "RegisterRequest",
    "UserOut",
    "LoginResponse",
    "GradeOut",
    "MajorOut",
    "ClassBrief",
    "ClassOut",
    "StudentOut",
    "StudentDetail",
    "TaskCreate",
    "TaskUpdate",
    "TaskOut",
    "RecordCreate",
    "RecordUpdate",
    "RecordOut",
]