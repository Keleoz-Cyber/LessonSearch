import os
from dotenv import load_dotenv

# 优先加载 server/.env，其次项目根目录 .env
_server_dir = os.path.dirname(os.path.abspath(__file__))
_env_local = os.path.join(_server_dir, ".env")
_env_root = os.path.join(_server_dir, "..", ".env")

if os.path.exists(_env_local):
    load_dotenv(_env_local)
else:
    load_dotenv(_env_root)

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "lesson_search")

DATABASE_URL = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
)
