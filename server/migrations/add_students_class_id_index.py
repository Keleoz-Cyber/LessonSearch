# -*- coding: utf-8 -*-
"""
Database migration: ensure students.class_id has index

Usage:
    cd server
    python migrations/add_students_class_id_index.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.database import engine
from sqlalchemy import text


def migrate():
    with engine.connect() as conn:
        # 检查索引是否存在
        result = conn.execute(
            text(
                "SHOW INDEX FROM students WHERE Key_name = 'idx_students_class_id'"
            )
        )
        if result.fetchone():
            print("idx_students_class_id 索引已存在，无需创建")
            return

        # 创建索引
        conn.execute(
            text("CREATE INDEX idx_students_class_id ON students(class_id)")
        )
        conn.commit()
        print("迁移完成：已创建 idx_students_class_id 索引")


if __name__ == "__main__":
    migrate()
