import os
from pathlib import Path
from dotenv import load_dotenv
from app.core.environment import DEFAULT_JWT_SECRET, database_url, select_env_file, validate_production

# 优先加载 server/.env，其次项目根目录 .env
_server_dir = Path(__file__).resolve().parents[2]
ENV_FILE = select_env_file(_server_dir, os.environ)
load_dotenv(ENV_FILE, override=False)
APP_ENV = os.getenv("APP_ENV", "development").lower()
validate_production(os.environ)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "lesson_search")

DATABASE_URL = database_url(os.environ)

# ============================================================
# 用户认证配置
# ============================================================

# JWT 配置
JWT_SECRET = os.getenv("JWT_SECRET", DEFAULT_JWT_SECRET)
JWT_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", "720"))  # 30天

# SMTP 配置（发送验证码）
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.qq.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "查课 App")
