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
            # 表已存在，检查 snapshot_data 字段类型
            col_result = conn.execute(
                text(
                    "SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS "
                    "WHERE TABLE_NAME = 'submission_snapshots' "
                    "AND COLUMN_NAME = 'snapshot_data'"
                )
            )
            row = col_result.fetchone()
            if row:
                data_type = row[0]
                if data_type.lower() != 'longtext':
                    print(f"snapshot_data 字段类型为 {data_type}，正在修改为 LONGTEXT...")
                    conn.execute(
                        text("ALTER TABLE submission_snapshots MODIFY snapshot_data LONGTEXT NOT NULL")
                    )
                    conn.commit()
                    print("修改完成：snapshot_data 已改为 LONGTEXT")
                else:
                    print("snapshot_data 已是 LONGTEXT，无需修改")
            else:
                print("未找到 snapshot_data 字段，跳过")
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
                    snapshot_data LONGTEXT NOT NULL,
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
