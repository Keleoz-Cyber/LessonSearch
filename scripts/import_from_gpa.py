# -*- coding: utf-8 -*-
"""
从绩点名单导入学生数据
用法:
    python import_from_gpa.py                # dry-run
    python import_from_gpa.py --commit       # 正式写入
    python import_from_gpa.py --commit --clear  # 清空旧数据后导入
"""
import argparse
import glob
import re
import sys
from pathlib import Path

import pandas as pd
from pypinyin import lazy_pinyin, Style
from sqlalchemy import select, delete, text

sys.path.insert(0, str(Path(__file__).parent))
from config import DATABASE_URL
from models import Base, engine, SessionLocal, Grade, Major, Class, Student

DATA_DIR = Path(__file__).parent.parent / "data" / "绩点名单"

MAJOR_SHORT_MAP = {
    "计算机科学与技术": "计科",
    "电子信息工程": "电信",
    "通信工程": "通信",
    "空间信息与数字技术": "空信",
    "物联网工程(中外合作办学)": "物联网",
    "计算机技术": "计技",
    "通信工程（含宽带网络、移动通信等）": "通信",
    "控制科学与工程": "控科",
    "电子信息": "电信",
    "信息与通信工程": "信通",
    "控制工程": "控工",
}


def parse_class_name(class_name: str) -> tuple:
    """解析班级名称，返回 (专业简称, 班级编号)
    例: '计科2202' -> ('计科', '02')
    """
    match = re.match(r"^([^\d]+)(\d+)$", class_name)
    if not match:
        return "", ""
    major_short = match.group(1)
    class_code = match.group(2)[-2:]
    return major_short, class_code


def generate_pinyin(name: str) -> tuple:
    full = "".join(lazy_pinyin(name, style=Style.TONE))
    abbr = "".join(lazy_pinyin(name, style=Style.FIRST_LETTER))
    return full, abbr


def import_students(commit: bool = False, clear: bool = False):
    files = glob.glob(str(DATA_DIR / "*.xlsx"))
    if not files:
        print(f"未找到Excel文件: {DATA_DIR}")
        return
    
    print(f"找到 {len(files)} 个Excel文件:")
    for f in files:
        print(f"  - {Path(f).name}")
    
    all_students = []
    grades = set()
    majors = set()
    classes = set()
    
    for file in files:
        print(f"\n读取: {Path(file).name}")
        df = pd.read_excel(file)
        
        for _, row in df.iterrows():
            student_no = str(row["学号"])
            name = str(row["姓名"])
            gender = str(row["性别"])
            class_name = str(row["班级"])
            major_full = str(row["专业名称"])
            year = int(row["年级"])
            
            major_short = MAJOR_SHORT_MAP.get(major_full, major_full[:2])
            _, class_code = parse_class_name(class_name)
            
            if not class_code:
                print(f"  [!] 无法解析班级: {class_name} ({name})")
                continue
            
            grades.add(year)
            majors.add((major_short, major_full))
            classes.add((year, major_short, class_code, class_name))
            
            pinyin_full, pinyin_abbr = generate_pinyin(name)
            all_students.append({
                "year": year,
                "major_short": major_short,
                "class_code": class_code,
                "class_name": class_name,
                "student_no": student_no,
                "name": name,
                "gender": gender,
                "pinyin": pinyin_full,
                "pinyin_abbr": pinyin_abbr,
            })
    
    print(f"\n统计:")
    print(f"  年级: {sorted(grades)}")
    print(f"  专业: {len(majors)} 个")
    for short, full in sorted(majors, key=lambda x: x[0]):
        print(f"    - {short}: {full}")
    print(f"  班级: {len(classes)} 个")
    print(f"  学生: {len(all_students)} 人")
    
    if not commit:
        print("\n[DRY-RUN] 未写入数据库")
        print("提示: 使用 --commit 正式写入，--commit --clear 清空旧数据")
        return
    
    session = SessionLocal()
    try:
        if clear:
            print("\n清空旧数据...")
            session.execute(text("DELETE FROM submission_records"))
            session.execute(text("DELETE FROM submissions"))
            session.execute(text("DELETE FROM attendance_records"))
            session.execute(text("DELETE FROM week_exports"))
            session.execute(text("DELETE FROM task_classes"))
            session.execute(text("DELETE FROM attendance_tasks"))
            session.execute(delete(Student))
            session.execute(delete(Class))
            session.execute(delete(Major))
            session.execute(delete(Grade))
            session.commit()
            print("  已清空")
        
        grade_map = {}
        for year in grades:
            grade = session.execute(select(Grade).where(Grade.year == year)).scalar_one_or_none()
            if not grade:
                grade = Grade(name=f"{year}级", year=year)
                session.add(grade)
                session.flush()
            grade_map[year] = grade
        
        major_map = {}
        for short, full in majors:
            major = session.execute(select(Major).where(Major.short_name == short)).scalar_one_or_none()
            if not major:
                major = Major(name=full, short_name=short)
                session.add(major)
                session.flush()
            major_map[short] = major
        
        class_map = {}
        for year, major_short, class_code, class_name in classes:
            grade = grade_map[year]
            major = major_map[major_short]
            cls = session.execute(
                select(Class).where(
                    Class.grade_id == grade.id,
                    Class.major_id == major.id,
                    Class.class_code == class_code,
                )
            ).scalar_one_or_none()
            if not cls:
                cls = Class(
                    grade_id=grade.id,
                    major_id=major.id,
                    class_code=class_code,
                    display_name=class_name,
                )
                session.add(cls)
                session.flush()
            class_map[(year, major_short, class_code)] = cls
        
        created = 0
        updated = 0
        for stu in all_students:
            cls = class_map[(stu["year"], stu["major_short"], stu["class_code"])]
            existing = session.execute(
                select(Student).where(Student.student_no == stu["student_no"])
            ).scalar_one_or_none()
            
            if existing:
                existing.name = stu["name"]
                existing.pinyin = stu["pinyin"]
                existing.pinyin_abbr = stu["pinyin_abbr"]
                existing.gender = stu["gender"]
                existing.class_id = cls.id
                updated += 1
            else:
                student = Student(
                    name=stu["name"],
                    student_no=stu["student_no"],
                    pinyin=stu["pinyin"],
                    pinyin_abbr=stu["pinyin_abbr"],
                    gender=stu["gender"],
                    class_id=cls.id,
                )
                session.add(student)
                created += 1
        
        session.commit()
        print(f"\n[OK] 导入完成: 新增 {created}, 更新 {updated}")
        
    except Exception as e:
        session.rollback()
        print(f"[ERROR] {e}")
        raise
    finally:
        session.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--commit", action="store_true", help="正式写入数据库")
    parser.add_argument("--clear", action="store_true", help="清空旧数据后导入")
    args = parser.parse_args()
    
    import_students(commit=args.commit, clear=args.clear)