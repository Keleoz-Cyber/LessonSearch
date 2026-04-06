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
    <body style="margin: 0; padding: 0; background-color: #fff0f5; font-family: 'PingFang SC', 'Microsoft YaHei', 'Helvetica Neue', Helvetica, Arial, sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 99%, #fecfef 100%); padding: 50px 15px;">
            <tr>
                <td align="center">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width: 480px; background-color: #ffffff; border-radius: 24px; overflow: hidden; box-shadow: 0 12px 30px rgba(255, 154, 158, 0.4);">
                        <tr>
                            <td style="padding: 45px 30px; text-align: center;">
                                <div style="font-size: 48px; margin-bottom: 10px; line-height: 1;">💌</div>
                                
                                <h2 style="margin-top: 0; color: #ff6b81; font-size: 26px; font-weight: bold;">
                                    你好呀！欢迎使用考勤助手 ✨
                                </h2>
                                <p style="color: #7a7a7a; font-size: 16px; line-height: 1.6; margin-bottom: 30px;">
                                    超级开心遇见你！🥰 你的专属魔法验证码已经准备好啦：
                                </p>
                                
                                <div style="background-color: #fff4f6; border: 2px dashed #ffb8c6; border-radius: 16px; padding: 25px; margin-bottom: 30px;">
                                    <span style="display: inline-block; font-size: 40px; font-weight: 900; color: #ff4757; letter-spacing: 12px; margin: 0; font-family: 'Courier New', Courier, monospace;">{code}</span>
                                </div>
                                
                                <p style="color: #7a7a7a; font-size: 15px; line-height: 1.6; margin-bottom: 35px;">
                                    💡 这个魔法代码在 <strong style="color: #ff4757;">5分钟</strong> 内有效哦，<br>千万不要偷偷告诉别人呀！🤫
                                </p>
                                
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td style="border-top: 2px dotted #ffeeee; padding-top: 25px;">
                                            <p style="color: #b2bec3; font-size: 13px; line-height: 1.6; margin: 0;">
                                                如果这不是你本人的操作，请不用理会，你的账号超级安全哒！🛡️<br>
                                                如果有任何小问号，随时呼唤学习部管理员哦。<br><br>
                                                <span style="color: #ff9a9e; font-weight: bold;">—— 考勤助手团队 欢快地敬上 🎈</span>
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