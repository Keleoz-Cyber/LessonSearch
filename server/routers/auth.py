import random
import smtplib
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
import jwt

from app.core.database import get_db
from app.models import User, VerificationCode, InvitationCode
from app.schemas import SendCodeRequest, LoginRequest, RegisterRequest, LoginResponse, UserOut
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
    current_date = datetime.now().strftime("%Y.%m.%d")

    body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f0f0eb; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f0f0eb; padding: 50px 15px;">
            <tr>
                <td align="center">
                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width: 500px; background-color: #ffffff; border: 3px solid #111111; box-shadow: 8px 8px 0px #111111; text-align: left;">
                        
                        <tr>
                            <td style="border-bottom: 3px solid #111111; padding: 12px 25px; background-color: #111111;">
                                <p style="color: #ffffff; font-family: 'Courier New', Courier, monospace; font-size: 13px; font-weight: bold; margin: 0; letter-spacing: 1px;">
                                    SYS.AUTH // 考勤助手_V2 // {current_date}
                                </p>
                            </td>
                        </tr>

                        <tr>
                            <td style="padding: 40px 30px;">
                                <h2 style="margin-top: 0; color: #111111; font-size: 28px; font-weight: 800; text-transform: uppercase; letter-spacing: -0.5px; margin-bottom: 20px;">
                                    身份验证协议
                                </h2>
                                <p style="color: #444444; font-size: 16px; line-height: 1.6; font-weight: 500; margin-bottom: 30px;">
                                    接收到新的授权请求。请提取下方的 6 位安全效验码，并录入系统终端以完成身份核实。
                                </p>
                                
                                <div style="background-color: #FF5722; border: 3px solid #111111; padding: 20px; text-align: center; margin-bottom: 30px;">
                                    <span style="display: inline-block; font-size: 46px; font-weight: 900; color: #111111; letter-spacing: 16px; margin: 0; font-family: 'Courier New', Courier, monospace; margin-right: -16px;">{code}</span>
                                </div>
                                
                                <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom: 30px;">
                                    <tr>
                                        <td width="50%" style="border: 2px solid #111111; padding: 12px; background-color: #f8f8f8;">
                                            <p style="margin: 0; font-size: 12px; color: #666; font-family: 'Courier New', Courier, monospace; font-weight: bold;">[ 有效状态 ]</p>
                                            <p style="margin: 5px 0 0 0; font-size: 15px; color: #111; font-weight: 800;">300 秒 (5分钟)</p>
                                        </td>
                                        <td width="10px"></td>
                                        <td width="50%" style="border: 2px solid #111111; padding: 12px; background-color: #f8f8f8;">
                                            <p style="margin: 0; font-size: 12px; color: #666; font-family: 'Courier New', Courier, monospace; font-weight: bold;">[ 安全级别 ]</p>
                                            <p style="margin: 5px 0 0 0; font-size: 15px; color: #111; font-weight: 800;">请勿泄露</p>
                                        </td>
                                    </tr>
                                </table>
                                
                                <p style="color: #666666; font-size: 13px; line-height: 1.6; margin: 0; padding-top: 20px; border-top: 2px dashed #cccccc;">
                                    * 异常报告：如未执行此操作，请忽略本指令。<br>
                                    * 技术支持：学习部系统管理员。<br><br>
                                    <strong style="color: #111111; font-size: 14px;">—— 考勤助手 DEV_TEAM</strong>
                                </p>
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


@router.get("/me", response_model=UserOut)
def get_me(user: User = Depends(get_current_user)):
    return UserOut(id=user.id, email=user.email, nickname=user.nickname)