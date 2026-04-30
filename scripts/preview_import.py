import pandas as pd
import glob
import re
from pathlib import Path
from pypinyin import lazy_pinyin, Style

DATA_DIR = Path("D:/study/code/Android/flutter/LessonSearch/data/绩点名单")

MAJOR_SHORT_MAP = {
    "计算机科学与技术": "计科",
    "电子信息工程": "电信",
    "通信工程": "通信",
    "空间信息与数字技术": "空信",
    "物联网工程(中外合作办学)": "物联网",
}

def parse_class_name(class_name):
    match = re.match(r"^([^\d]+)(\d+)$", class_name)
    if not match:
        return "", ""
    major_short = match.group(1)
    class_code = match.group(2)[-2:]
    return major_short, class_code

files = glob.glob(str(DATA_DIR / "*.xlsx"))
all_students = []
grades = set()
majors = set()
classes = set()

for file in files:
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
            continue
        
        grades.add(year)
        majors.add((major_short, major_full))
        classes.add((year, major_short, class_code, class_name))
        all_students.append({
            "year": year,
            "major_short": major_short,
            "class_code": class_code,
            "class_name": class_name,
            "student_no": student_no,
            "name": name,
            "gender": gender,
        })

output_path = Path("D:/study/code/Android/flutter/LessonSearch/import_preview.txt")
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(f"统计:\n")
    f.write(f"  年级: {sorted(grades)}\n")
    f.write(f"  专业: {len(majors)} 个\n")
    for short, full in sorted(majors, key=lambda x: x[0]):
        f.write(f"    - {short}: {full}\n")
    f.write(f"  班级: {len(classes)} 个\n")
    f.write(f"  学生: {len(all_students)} 人\n\n")
    f.write("样本数据:\n")
    for stu in all_students[:10]:
        f.write(f"  {stu['student_no']} | {stu['name']} | {stu['gender']} | {stu['class_name']} | {stu['year']}\n")

print(f"Written to: {output_path}")