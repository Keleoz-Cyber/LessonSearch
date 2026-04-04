"""
生成邀请码脚本

使用方法（在服务器 /opt/lesson-search 目录）：
  source venv/bin/activate
  cd server
  python ../scripts/generate_invitation_codes.py <数量>
  
例如：
  python ../scripts/generate_invitation_codes.py 20
"""
import sys
import secrets
import string

# 添加 server 目录到路径
sys.path.insert(0, '.')

from database import SessionLocal
from models import InvitationCode


def generate_code(length: int = 8) -> str:
    """生成随机邀请码"""
    chars = string.ascii_lowercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))


def main():
    if len(sys.argv) < 2:
        print("用法: python scripts/generate_invitation_codes.py <数量>")
        print("需要在 server 目录下运行")
        sys.exit(1)
    
    count = int(sys.argv[1])
    
    db = SessionLocal()
    try:
        codes = []
        for _ in range(count):
            code = generate_code()
            inv = InvitationCode(code=code)
            db.add(inv)
            codes.append(code)
        
        db.commit()
        
        print(f"成功生成 {count} 个邀请码:")
        for code in codes:
            print(f"  {code}")
        
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    main()