from app.schemas.user import (
    SendCodeRequest,
    LoginRequest,
    RegisterRequest,
    PasswordLoginRequest,
    SetPasswordRequest,
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
from app.schemas.record import (
    RecordCreate,
    RecordUpdate,
    RecordOut,
    RecordBatchUpdateItem,
    RecordBatchUpdateResult,
)

__all__ = [
    "SendCodeRequest",
    "LoginRequest",
    "RegisterRequest",
    "PasswordLoginRequest",
    "SetPasswordRequest",
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
    "RecordBatchUpdateItem",
    "RecordBatchUpdateResult",
]