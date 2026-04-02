import os
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "lesson_search")

DATABASE_URL = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}?charset=utf8mb4"
)

# Excel 数据目录（相对于项目根目录）
EXCEL_DATA_DIR = os.getenv("EXCEL_DATA_DIR", os.path.join(os.path.dirname(__file__), "..", "data", "考勤表"))

# 专业关键词映射：缩写 → 全称
MAJOR_MAPPING = {
    "电信": "电子信息工程",
    "计科": "计算机科学与技术",
    "空信": "空间信息与数字技术",
    "通信": "通信工程",
    "物联网": "物联网工程",
}
