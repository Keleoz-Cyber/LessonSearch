"""
v0.5.0 数据库迁移脚本

执行方式：
cd server
source ../venv/bin/activate  # 如果服务器上有虚拟环境
python ../scripts/migrate_v050.py

或直接在服务器执行：
mysql -u lesson_search -p lesson_search < ../scripts/migrate_v050.sql
"""
import sys
import os

# 添加 server 目录到路径
server_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(server_dir, "server"))

from dotenv import load_dotenv
load_dotenv(os.path.join(server_dir, "server", ".env"))

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "lesson_search")

DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"

from sqlalchemy import create_engine, text


def migrate():
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        # 1. 修改 users 表
        print("1. 修改 users 表...")
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'member'"))
            print("   - 添加 role 字段")
        except Exception as e:
            if "Duplicate column" in str(e):
                print("   - role 字段已存在，跳过")
            else:
                raise
        
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN real_name VARCHAR(50)"))
            print("   - 添加 real_name 字段")
        except Exception as e:
            if "Duplicate column" in str(e):
                print("   - real_name 字段已存在，跳过")
            else:
                raise
        
        conn.commit()
        
        # 2. 创建 week_config 表
        print("2. 创建 week_config 表...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS week_config (
                id INT PRIMARY KEY AUTO_INCREMENT,
                start_date DATE NOT NULL,
                semester_name VARCHAR(50),
                is_active BOOLEAN DEFAULT TRUE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """))
        conn.commit()
        print("   - 完成")
        
        # 3. 创建 submissions 表
        print("3. 创建 submissions 表...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS submissions (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                week_number INT NOT NULL,
                status VARCHAR(20) DEFAULT 'pending',
                reviewer_id INT,
                review_time DATETIME,
                review_note TEXT,
                submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (reviewer_id) REFERENCES users(id),
                INDEX idx_user_week (user_id, week_number),
                INDEX idx_status (status),
                INDEX idx_week (week_number)
            )
        """))
        conn.commit()
        print("   - 完成")
        
        # 4. 创建 submission_records 表
        print("4. 创建 submission_records 表...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS submission_records (
                id INT PRIMARY KEY AUTO_INCREMENT,
                submission_id INT NOT NULL,
                record_id INT NOT NULL,
                FOREIGN KEY (submission_id) REFERENCES submissions(id),
                FOREIGN KEY (record_id) REFERENCES attendance_records(id),
                UNIQUE KEY uk_record (record_id)
            )
        """))
        conn.commit()
        print("   - 完成")
        
        # 5. 创建 week_exports 表
        print("5. 创建 week_exports 表...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS week_exports (
                id INT PRIMARY KEY AUTO_INCREMENT,
                week_number INT NOT NULL,
                exported_by INT NOT NULL,
                exported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (exported_by) REFERENCES users(id),
                INDEX idx_week (week_number)
            )
        """))
        conn.commit()
        print("   - 完成")
        
        # 6. 创建 duty_assignments 表
        print("6. 创建 duty_assignments 表...")
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS duty_assignments (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                assigned_by INT NOT NULL,
                assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT TRUE,
                deactivated_at DATETIME,
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (assigned_by) REFERENCES users(id),
                UNIQUE KEY uk_user (user_id)
            )
        """))
        conn.commit()
        print("   - 完成")
        
        print("\n迁移完成！")


if __name__ == "__main__":
    migrate()