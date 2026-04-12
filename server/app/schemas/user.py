from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


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
    real_name: Optional[str] = None
    role: str = "member"
    is_new_user: bool = False

    model_config = {"from_attributes": True}


class LoginResponse(BaseModel):
    token: str
    user: UserOut


class UpdateRealNameRequest(BaseModel):
    real_name: str


class AdminResponse(BaseModel):
    id: int
    email: str
    real_name: Optional[str] = None
    nickname: Optional[str] = None

    model_config = {"from_attributes": True}