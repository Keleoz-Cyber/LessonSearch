"""
数据库迁移脚本：为用户表添加 password_hash 字段

运行方式：
    cd server
    python migrations/add_password_hash.py

或手动在 MySQL 中执行：
    ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL;
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.database import engine
from sqlalchemy import text


def migrate():
    with engine.connect() as conn:
        # 检查 password_hash 字段是否已存在
        result = conn.execute(
            text(
                "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS "
                "WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'password_hash'"
            )
        )
        if result.fetchone():
            print("password_hash 字段已存在，无需迁移")
            return

        # 添加字段
        conn.execute(
            text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL")
        )
        conn.commit()
        print("迁移完成：已添加 password_hash 字段")


if __name__ == "__main__":
    migrate()
