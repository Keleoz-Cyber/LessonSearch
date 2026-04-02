"""
建表脚本：创建 MySQL 数据库表。

用法:
    python init_db.py              # 创建表（已存在则跳过）
    python init_db.py --reset      # 删除并重建所有表（危险！）
"""
import argparse
import sys

from sqlalchemy import inspect, text

from models import Base, engine


def create_tables():
    """创建所有表（已存在则跳过）"""
    Base.metadata.create_all(engine)
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f"当前数据库中的表: {tables}")


def reset_tables():
    """删除并重建所有表"""
    print("警告：将删除所有表并重建！")
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    print(f"表已重建: {tables}")


def check_connection():
    """测试数据库连接"""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("数据库连接成功")
        return True
    except Exception as e:
        print(f"数据库连接失败: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="初始化数据库表")
    parser.add_argument("--reset", action="store_true", help="删除并重建所有表")
    args = parser.parse_args()

    if not check_connection():
        sys.exit(1)

    if args.reset:
        confirm = input("确认删除所有表并重建？(yes/no): ")
        if confirm.lower() != "yes":
            print("已取消")
            sys.exit(0)
        reset_tables()
    else:
        create_tables()

    print("完成")


if __name__ == "__main__":
    main()
