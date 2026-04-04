import random
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
import jwt

from database import get_db
from models import User, VerificationCode, AttendanceTask
from schemas import SendCodeRequest, LoginRequest, LoginResponse, UserOut
from config import (
    INVITATION_CODES,
    JWT_SECRET,
    JWT_EXPIRE_HOURS,
    SMTP_HOST,
    SMTP_PORT,
    SMTP_USER,
    SMTP_PASSWORD,
    SMTP_FROM_NAME,
)

router = APIRouter(prefix="/auth", tags=["认证"])


def _send_email(to: str, code: str):
    if not SMTP_USER or not SMTP_PASSWORD:
        raise HTTPException(status_code=500, detail="SMTP 未配置")

    subject = f"{SMTP_FROM_NAME} 登录验证码"
    body = f"""
    <p>您的登录验证码是：<strong style="font-size:24px;color:#2196F3">{code}</strong></p>
    <p>验证码 5 分钟内有效，请勿泄露给他人。</p>
    <p>—— {SMTP_FROM_NAME}</p>
    """

    msg = MIMEText(body, "html", "utf-8")
    msg["Subject"] = subject
    msg["From"] = SMTP_USER
    msg["To"] = to

    with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as server:
        server.login(SMTP_USER, SMTP_PASSWORD)
        server.sendmail(SMTP_USER, [to], msg.as_string())


def _create_token(user_id: int) -> str:
    payload = {
        "user_id": user_id,
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def _verify_token(token: str) -> int:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload["user_id"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token 已过期")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token 无效")


def get_current_user(
    authorization: str | None = Header(None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="未登录")

    token = authorization.removeprefix("Bearer ")
    user_id = _verify_token(token)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")

    return user


@router.post("/send-code")
def send_code(body: SendCodeRequest, db: Session = Depends(get_db)):
    existing = db.query(VerificationCode).filter(
        VerificationCode.email == body.email,
        VerificationCode.used == False,
        VerificationCode.expires_at > datetime.utcnow(),
    ).first()

    if existing and existing.created_at > datetime.utcnow() - timedelta(seconds=60):
        raise HTTPException(status_code=429, detail="请等待 60 秒后再发送")

    code = str(random.randint(100000, 999999))
    expires_at = datetime.utcnow() + timedelta(minutes=5)

    vc = VerificationCode(
        email=body.email,
        code=code,
        expires_at=expires_at,
    )
    db.add(vc)
    db.commit()

    _send_email(body.email, code)

    return {"message": "验证码已发送"}


@router.post("/login", response_model=LoginResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    if body.invitation_code not in INVITATION_CODES:
        raise HTTPException(status_code=400, detail="邀请码无效")

    vc = db.query(VerificationCode).filter(
        VerificationCode.email == body.email,
        VerificationCode.code == body.code,
        VerificationCode.used == False,
        VerificationCode.expires_at > datetime.utcnow(),
    ).first()

    if not vc:
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    vc.used = True

    user = db.query(User).filter(User.email == body.email).first()
    is_new_user = False

    if not user:
        user = User(email=body.email)
        db.add(user)
        db.flush()
        is_new_user = True

    user.last_login_at = datetime.utcnow()
    db.commit()
    db.refresh(user)

    token = _create_token(user.id)

    return LoginResponse(
        token=token,
        user=UserOut(id=user.id, email=user.email, nickname=user.nickname, is_new_user=is_new_user),
    )


@router.get("/me", response_model=UserOut)
def get_me(user: User = Depends(get_current_user)):
    return UserOut(id=user.id, email=user.email, nickname=user.nickname)