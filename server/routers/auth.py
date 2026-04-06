import random
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
import jwt

from database import get_db
from models import User, VerificationCode, InvitationCode
from schemas import SendCodeRequest, LoginRequest, RegisterRequest, LoginResponse, UserOut
from config import (
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

    subject = "考勤助手APP验证码 ✨"
    
    body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f4f7f6; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #8E2DE2 0%, #4A00E0 100%); padding: 40px 15px;">
            <tr>
                <td align="center">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width: 500px; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 8px 20px rgba(0,0,0,0.15);">
                        <tr>
                            <td style="padding: 40px 30px;">
                                <h2 style="margin-top: 0; color: #333333; text-align: center; font-size: 24px;">
                                    欢迎使用考勤助手 👋
                                </h2>
                                <p style="color: #666666; font-size: 16px; line-height: 1.6; margin-bottom: 25px; text-align: center;">
                                    您好！感谢您使用我们的服务。您的验证码如下：
                                </p>
                                
                                <div style="background-color: #f8f9fa; border: 1px dashed #cba4f4; border-radius: 8px; padding: 20px; text-align: center; margin-bottom: 25px;">
                                    <span style="display: inline-block; font-size: 36px; font-weight: bold; color: #6a11cb; letter-spacing: 10px; margin: 0;">{code}</span>
                                </div>
                                
                                <p style="color: #666666; font-size: 14px; line-height: 1.6; text-align: center; margin-bottom: 30px;">
                                    该验证码在 <strong style="color: #e53e3e;">5分钟</strong> 内有效。请勿将验证码泄露给他人。 ⏱️
                                </p>
                                
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td style="border-top: 1px solid #eeeeee; padding-top: 20px;">
                                            <p style="color: #999999; font-size: 12px; line-height: 1.5; text-align: center; margin: 0;">
                                                如果这不是您的操作，请忽略此邮件，您的账户是安全的。<br>
                                                如有任何问题，请联系学习部管理员。 📧<br><br>
                                                —— 考勤助手团队 敬上 ✨
                                            </p>
                                        </td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>
    </body>
    </html>
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
        "exp": datetime.now() + timedelta(hours=JWT_EXPIRE_HOURS),
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
        VerificationCode.expires_at > datetime.now(),
    ).first()

    if existing and existing.created_at > datetime.now() - timedelta(seconds=60):
        raise HTTPException(status_code=429, detail="请等待 60 秒后再发送")

    code = str(random.randint(100000, 999999))
    expires_at = datetime.now() + timedelta(minutes=5)

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
    import sys
    print(f"[DEBUG] login body: {body}", file=sys.stderr)
    
    vc = db.query(VerificationCode).filter(
        VerificationCode.email == body.email,
        VerificationCode.code == body.code,
        VerificationCode.used == False,
        VerificationCode.expires_at > datetime.now(),
    ).first()

    if not vc:
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    user = db.query(User).filter(User.email == body.email).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="账户不存在，请先注册")

    vc.used = True
    user.last_login_at = datetime.now()
    db.commit()
    db.refresh(user)

    token = _create_token(user.id)

    return LoginResponse(
        token=token,
        user=UserOut(id=user.id, email=user.email, nickname=user.nickname, is_new_user=False),
    )


@router.post("/register", response_model=LoginResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    vc = db.query(VerificationCode).filter(
        VerificationCode.email == body.email,
        VerificationCode.code == body.code,
        VerificationCode.used == False,
        VerificationCode.expires_at > datetime.now(),
    ).first()

    if not vc:
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    existing_user = db.query(User).filter(User.email == body.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="该邮箱已注册，请直接登录")

    inv_code = db.query(InvitationCode).filter(
        InvitationCode.code == body.invitation_code,
    ).first()
    
    if not inv_code:
        raise HTTPException(status_code=400, detail="邀请码无效")
    
    if inv_code.used:
        raise HTTPException(status_code=400, detail="邀请码已被使用")

    vc.used = True
    
    user = User(email=body.email)
    db.add(user)
    db.flush()
    
    inv_code.used = True
    inv_code.used_by = user.id
    inv_code.used_at = datetime.now()
    
    user.last_login_at = datetime.now()
    db.commit()
    db.refresh(user)

    token = _create_token(user.id)

    return LoginResponse(
        token=token,
        user=UserOut(id=user.id, email=user.email, nickname=user.nickname, is_new_user=True),
    )


@router.get("/me", response_model=UserOut)
def get_me(user: User = Depends(get_current_user)):
    return UserOut(id=user.id, email=user.email, nickname=user.nickname)