import random
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from fastapi import APIRouter, Depends, HTTPException, Header, Response
from sqlalchemy.orm import Session
import jwt
import bcrypt

from app.core.database import get_db
from app.models import User, VerificationCode, InvitationCode
from app.schemas import (
    SendCodeRequest, LoginRequest, RegisterRequest,
    PasswordLoginRequest, SetPasswordRequest,
    LoginResponse, UserOut,
)

from app.core.config import (
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

    subject = "考勤助手 验证码"

    body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>考勤助手-梦幻验证码</title>
        <style>
            @keyframes border-glow {{
                0% {{ box-shadow: 0 0 15px rgba(255, 182, 193, 0.4); border-color: rgba(255, 255, 255, 0.5); }}
                50% {{ box-shadow: 0 0 35px rgba(135, 206, 250, 0.7); border-color: rgba(255, 255, 255, 0.9); }}
                100% {{ box-shadow: 0 0 15px rgba(255, 182, 193, 0.4); border-color: rgba(255, 255, 255, 0.5); }}
            }}
            .glow-card {{
                animation: border-glow 4s ease-in-out infinite;
            }}
        </style>
    </head>
    <body style="margin: 0; padding: 0; background-color: #fdfbfb; font-family: 'SF Pro Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; -webkit-font-smoothing: antialiased;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-image: linear-gradient(135deg, #ff9a9e 0%, #fad0c4 10%, #fad0c4 20%, #a1c4fd 50%, #c2e9fb 80%, #ff9a9e 100%); padding: 50px 15px;">
            <tr>
                <td align="center">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="glow-card" style="max-width: 480px; background-color: rgba(255, 255, 255, 0.85); border-radius: 24px; border: 2px solid rgba(255, 255, 255, 0.6); overflow: hidden; backdrop-filter: blur(10px); box-shadow: 0 15px 35px rgba(0,0,0,0.05); text-align: center;">
                        <tr>
                            <td style="padding: 50px 30px;">
                                <div style="font-size: 56px; margin-bottom: 20px; line-height: 1;">🪐</div>
                                
                                <h2 style="margin-top: 0; background-image: linear-gradient(to right, #ff758c 0%, #ff7eb3 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">
                                    专属你的时刻，开始啦✨
                                </h2>
                                <p style="color: #6a6a7a; font-size: 16px; line-height: 1.6; margin-bottom: 30px;">
                                    欢迎来到考勤助手的梦幻空间。请使用下方的时空密钥，开启您的新体验：
                                </p>
                                
                                <div class="glow-card" style="background: linear-gradient(135deg, rgba(255, 117, 140, 0.05) 0%, rgba(255, 126, 179, 0.05) 100%); border: 1px dashed rgba(255, 117, 140, 0.3); border-radius: 16px; padding: 25px; margin-bottom: 30px; display: inline-block;">
                                    <span style="font-size: 48px; font-weight: 800; color: #ff6b81; letter-spacing: 16px; font-family: 'Courier New', Courier, monospace; text-shadow: 0 0 10px rgba(255, 107, 129, 0.3);">{code}</span>
                                </div>
                                
                                <p style="color: #8c8ca0; font-size: 14px; line-height: 1.6; margin-bottom: 40px;">
                                    ⏱️ 这个魔法密钥将在 <strong style="color: #ff6b81;">5分钟</strong> 后化作星尘。<br>请妥善保管，切勿分享给他人。🤫
                                </p>
                                
                                <table width="100%" cellpadding="0" cellspacing="0" border="0">
                                    <tr>
                                        <td style="border-top: 1px solid rgba(0,0,0,0.05); padding-top: 25px;">
                                            <p style="color: #b0b0c0; font-size: 12px; line-height: 1.6; margin: 0;">
                                                如果您未请求此操作，请忽略此邮件，您的账户依然安全。🛡️<br>
                                                如有任何小问号，随时联系管理员。<br><br>
                                                <span style="color: #a1c4fd; font-weight: bold;">—— 考勤助手梦幻 DEV_TEAM 💫</span>
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
    from datetime import timezone
    payload = {
        "user_id": user_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS),
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
    response: Response = None,
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="未登录")

    token = authorization.removeprefix("Bearer ")
    user_id = _verify_token(token)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="用户不存在")

    # Token 自动刷新：如果剩余有效期 < 7 天，生成新 Token
    if response:
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            from datetime import timezone
            exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
            remaining = exp - datetime.now(timezone.utc)
            if remaining < timedelta(days=7):
                new_token = _create_token(user.id)
                response.headers["X-Token-Refresh"] = new_token
        except Exception:
            pass

    return user


@router.post("/send-code")
def send_code(body: SendCodeRequest, db: Session = Depends(get_db)):
    import sys
    print(f"[DEBUG] send-code body: {body}", file=sys.stderr)
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

    return {
        "token": token,
        "user": {
            "id": user.id,
            "email": user.email,
            "nickname": user.nickname,
            "real_name": user.real_name,
            "role": user.role or "member",
            "is_new_user": False
        }
    }


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

    return {
        "token": token,
        "user": {
            "id": user.id,
            "email": user.email,
            "nickname": user.nickname,
            "real_name": user.real_name,
            "role": user.role or "member",
            "is_new_user": True
        }
    }


def _hash_password(password: str) -> str:
    # bcrypt has a 72-byte limit; encode to UTF-8 and let bcrypt handle truncation safely
    password_bytes = password.encode("utf-8")
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode("utf-8")


def _verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except Exception:
        return False


@router.post("/password-login", response_model=LoginResponse)
def password_login(body: PasswordLoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == body.email).first()
    if not user:
        raise HTTPException(status_code=400, detail="账户不存在")

    if not user.password_hash:
        raise HTTPException(
            status_code=400, detail="该账号尚未设置密码，请先使用验证码登录"
        )

    if not _verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=400, detail="密码错误")

    user.last_login_at = datetime.now()
    db.commit()
    db.refresh(user)

    token = _create_token(user.id)

    return {
        "token": token,
        "user": {
            "id": user.id,
            "email": user.email,
            "nickname": user.nickname,
            "real_name": user.real_name,
            "role": user.role or "member",
            "is_new_user": False,
        },
    }


@router.post("/set-password")
def set_password(
    body: SetPasswordRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if len(body.password) < 6:
        raise HTTPException(status_code=400, detail="密码至少需要 6 位")

    user.password_hash = _hash_password(body.password)
    db.commit()

    return {"message": "密码设置成功"}


@router.get("/me")
def get_me(user: User = Depends(get_current_user)):
    return {
        "id": user.id,
        "email": user.email,
        "nickname": user.nickname,
        "real_name": user.real_name,
        "role": user.role or "member",
        "has_password": user.password_hash is not None,
    }