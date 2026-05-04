# -*- coding: utf-8 -*-
"""
Database migration: add submission_snapshots table

Usage:
    cd server
    python migrations/add_submission_snapshots.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.database import engine
from sqlalchemy import text


def migrate():
    with engine.connect() as conn:
        # 检查表是否已存在
        result = conn.execute(
            text(
                "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_NAME = 'submission_snapshots'"
            )
        )
        if result.fetchone():
            print("submission_snapshots 表已存在，无需迁移")
            return

        # 创建表
        conn.execute(
            text("""
                CREATE TABLE submission_snapshots (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    submission_id INT NOT NULL UNIQUE,
                    week_number INT NOT NULL,
                    user_id INT NOT NULL,
                    class_names VARCHAR(200) NULL,
                    snapshot_data TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (submission_id) REFERENCES submissions(id),
                    INDEX idx_snapshot_week (week_number),
                    INDEX idx_snapshot_user (user_id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """)
        )
        conn.commit()
        print("迁移完成：已创建 submission_snapshots 表")


if __name__ == "__main__":
    migrate()
