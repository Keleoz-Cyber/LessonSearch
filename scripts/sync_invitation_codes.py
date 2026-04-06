"""
从 .env 同步邀请码到数据库

使用方法（在服务器 /opt/lesson-search 目录）：
  source venv/bin/activate
  cd server
  python ../scripts/sync_invitation_codes.py
"""
import sys
import os
from dotenv import load_dotenv

sys.path.insert(0, '.')

from app.core.database import SessionLocal
from app.models import InvitationCode


def main():
    # 加载 .env
    load_dotenv()
    
    codes_str = os.getenv('INVITATION_CODES', '')
    if not codes_str:
        print("错误: .env 中没有 INVITATION_CODES 配置")
        sys.exit(1)
    
    codes = [c.strip() for c in codes_str.split(',')]
    
    db = SessionLocal()
    try:
        added = 0
        skipped = 0
        
        for code in codes:
            # 检查是否已存在
            existing = db.query(InvitationCode).filter(
                InvitationCode.code == code
            ).first()
            
            if existing:
                skipped += 1
                print(f"  跳过（已存在）: {code}")
            else:
                inv = InvitationCode(code=code)
                db.add(inv)
                added += 1
                print(f"  添加: {code}")
        
        db.commit()
        
        print(f"\n同步完成:")
        print(f"  新增: {added}")
        print(f"  跳过: {skipped}")
        print(f"  总计: {len(codes)}")
        
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    main()