from pydantic import BaseModel, EmailStr


class SendCodeRequest(BaseModel):
    email: EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    code: str


class RegisterRequest(BaseModel):
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