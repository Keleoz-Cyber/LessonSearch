"""
Excel 数据导入器：将分析器的结果清洗后写入 MySQL。

用法:
    python excel_importer.py                    # dry-run 模式（只分析不写入）
    python excel_importer.py --commit           # 正式写入数据库
    python excel_importer.py --commit --force   # 强制重新导入（更新已有记录）
    python excel_importer.py --dir /path/to/data  # 指定数据目录

依赖: excel_analyzer.py 的分析结果。
"""
import argparse
import sys
from datetime import datetime

from pypinyin import lazy_pinyin, Style
from sqlalchemy import select

from config import EXCEL_DATA_DIR, MAJOR_MAPPING
from models import Base, engine, SessionLocal, Grade, Major, Class, Student
from excel_analyzer import scan_and_analyze, AnalysisReport, parse_class_label


# ============================================================
# 拼音生成
# ============================================================

def generate_pinyin(name: str) -> tuple[str, str]:
    """
    生成姓名拼音和缩写。
    '张三' → ('zhangsan', 'zs')
    """
    full = "".join(lazy_pinyin(name, style=Style.NORMAL))
    abbr = "".join(lazy_pinyin(name, style=Style.FIRST_LETTER))
    return full, abbr


# ============================================================
# 导入逻辑
# ============================================================

class ImportResult:
    def __init__(self):
        self.grades_created = 0
        self.majors_created = 0
        self.classes_created = 0
        self.students_created = 0
        self.students_updated = 0
        self.students_skipped = 0
        self.warnings: list[str] = []
        self.errors: list[str] = []

    def summary(self) -> str:
        lines = [
            "=" * 50,
            "导入结果汇总",
            "=" * 50,
            f"年级: 新增 {self.grades_created}",
            f"专业: 新增 {self.majors_created}",
            f"班级: 新增 {self.classes_created}",
            f"学生: 新增 {self.students_created}, 更新 {self.students_updated}, 跳过 {self.students_skipped}",
        ]
        if self.warnings:
            lines.append(f"\n警告 ({len(self.warnings)} 条):")
            for w in self.warnings:
                lines.append(f"  [!] {w}")
        if self.errors:
            lines.append(f"\n错误 ({len(self.errors)} 条):")
            for e in self.errors:
                lines.append(f"  [X] {e}")
        return "\n".join(lines)


def get_or_create_grade(session, year: int) -> Grade:
    """获取或创建年级"""
    grade = session.execute(
        select(Grade).where(Grade.year == year)
    ).scalar_one_or_none()
    if not grade:
        grade = Grade(name=f"{year}级", year=year)
        session.add(grade)
        session.flush()
    return grade


def get_or_create_major(session, short_name: str, full_name: str) -> Major:
    """获取或创建专业"""
    major = session.execute(
        select(Major).where(Major.short_name == short_name)
    ).scalar_one_or_none()
    if not major:
        major = Major(name=full_name, short_name=short_name)
        session.add(major)
        session.flush()
    return major


def get_or_create_class(session, grade: Grade, major: Major, class_code: str) -> Class:
    """获取或创建班级（按 grade_id + major_id + class_code 唯一）"""
    cls = session.execute(
        select(Class).where(
            Class.grade_id == grade.id,
            Class.major_id == major.id,
            Class.class_code == class_code,
        )
    ).scalar_one_or_none()
    if not cls:
        display_name = f"{major.short_name}{class_code}班"
        cls = Class(
            grade_id=grade.id,
            major_id=major.id,
            class_code=class_code,
            display_name=display_name,
        )
        session.add(cls)
        session.flush()
    return cls


def import_from_report(report: AnalysisReport, commit: bool = False, force: bool = False) -> ImportResult:
    """
    根据分析报告执行导入。支持考勤表格式和名单格式。
    """
    result = ImportResult()

    if report.errors:
        result.errors.extend(report.errors)
        return result

    session = SessionLocal()

    try:
        grade_cache: dict[int, Grade] = {}
        major_cache: dict[str, Major] = {}
        class_cache: dict[str, Class] = {}

        def ensure_grade(year: int) -> Grade:
            if year not in grade_cache:
                grade_cache[year] = get_or_create_grade(session, year)
                result.grades_created += 1
            return grade_cache[year]

        def ensure_major(short: str) -> Major:
            if short not in major_cache:
                full = MAJOR_MAPPING.get(short, short)
                major_cache[short] = get_or_create_major(session, short, full)
                result.majors_created += 1
            return major_cache[short]

        def ensure_class(grade: Grade, major: Major, code: str) -> Class:
            key = f"{major.short_name}_{code}"
            if key not in class_cache:
                class_cache[key] = get_or_create_class(session, grade, major, code)
                result.classes_created += 1
            return class_cache[key]

        def import_student(stu_name: str, stu_no: str, cls: Class):
            existing = session.execute(
                select(Student).where(Student.student_no == stu_no)
            ).scalar_one_or_none()

            if existing:
                if force:
                    pinyin_full, pinyin_abbr = generate_pinyin(stu_name)
                    existing.name = stu_name
                    existing.pinyin = pinyin_full
                    existing.pinyin_abbr = pinyin_abbr
                    existing.class_id = cls.id
                    result.students_updated += 1
                else:
                    result.students_skipped += 1
                return

            pinyin_full, pinyin_abbr = generate_pinyin(stu_name)
            student = Student(
                name=stu_name,
                student_no=stu_no,
                pinyin=pinyin_full,
                pinyin_abbr=pinyin_abbr,
                class_id=cls.id,
            )
            session.add(student)
            result.students_created += 1

        for fa in report.files:
            for sa in fa.sheets:
                if sa.format_type == "roster":
                    # 名单格式: 每个学生自带 class_label，从中解析年级/专业/班级
                    for stu in sa.students:
                        if not stu.class_label:
                            result.warnings.append(
                                f"跳过 {fa.file_name}/{sa.sheet_name} Row {stu.row_number}: "
                                f"{stu.name} 无班级信息"
                            )
                            continue

                        m_short, c_code, g_year = parse_class_label(stu.class_label)
                        if not m_short or not c_code or not g_year:
                            result.warnings.append(
                                f"跳过 {fa.file_name}/{sa.sheet_name} Row {stu.row_number}: "
                                f"无法解析班级 '{stu.class_label}'"
                            )
                            continue

                        grade = ensure_grade(g_year)
                        major = ensure_major(m_short)
                        cls = ensure_class(grade, major, c_code)
                        import_student(stu.name, stu.student_no, cls)
                else:
                    # 考勤表格式: 年级/专业来自文件级别，班级来自 sheet
                    if not fa.grade_year:
                        result.warnings.append(f"跳过 {fa.file_name}: 无法确定年级")
                        continue
                    if not fa.major_short:
                        result.warnings.append(f"跳过 {fa.file_name}: 无法确定专业")
                        continue
                    if not sa.class_code:
                        result.warnings.append(
                            f"跳过 {fa.file_name}/{sa.sheet_name}: 无法确定班级编号"
                        )
                        continue

                    grade = ensure_grade(fa.grade_year)
                    major = ensure_major(fa.major_short)
                    cls = ensure_class(grade, major, sa.class_code)

                    for stu in sa.students:
                        import_student(stu.name, stu.student_no, cls)

        if commit:
            session.commit()
            print("[OK] 数据已写入数据库")
        else:
            session.rollback()
            print("[DRY-RUN] 未写入数据库，以上为模拟结果")

    except Exception as e:
        session.rollback()
        result.errors.append(f"导入出错: {e}")
        raise
    finally:
        session.close()

    return result


# ============================================================
# 入口
# ============================================================

def preview_from_report(report: AnalysisReport) -> ImportResult:
    """纯本地预览模式：不连接数据库，只统计将要导入的数据。"""
    result = ImportResult()
    grade_years = set()
    major_shorts = set()
    class_codes = set()

    for fa in report.files:
        for sa in fa.sheets:
            if sa.format_type == "roster":
                for stu in sa.students:
                    if not stu.class_label:
                        continue
                    m_short, c_code, g_year = parse_class_label(stu.class_label)
                    if not m_short or not c_code or not g_year:
                        continue
                    if g_year not in grade_years:
                        grade_years.add(g_year)
                        result.grades_created += 1
                    if m_short not in major_shorts:
                        major_shorts.add(m_short)
                        result.majors_created += 1
                    class_key = f"{m_short}_{c_code}"
                    if class_key not in class_codes:
                        class_codes.add(class_key)
                        result.classes_created += 1
                    result.students_created += 1
            else:
                if not fa.grade_year or not fa.major_short:
                    continue
                if not sa.class_code:
                    continue
                if fa.grade_year not in grade_years:
                    grade_years.add(fa.grade_year)
                    result.grades_created += 1
                if fa.major_short not in major_shorts:
                    major_shorts.add(fa.major_short)
                    result.majors_created += 1
                class_key = f"{fa.major_short}_{sa.class_code}"
                if class_key not in class_codes:
                    class_codes.add(class_key)
                    result.classes_created += 1
                result.students_created += len(sa.students)

    # 拼音预览
    sample_students = []
    for fa in report.files:
        for sa in fa.sheets:
            for stu in sa.students:
                if len(sample_students) < 3:
                    pinyin_full, pinyin_abbr = generate_pinyin(stu.name)
                    sample_students.append(
                        f"  {stu.name} → {pinyin_full} ({pinyin_abbr})"
                    )
    if sample_students:
        result.warnings.append("拼音生成预览:\n" + "\n".join(sample_students))

    return result


def main():
    parser = argparse.ArgumentParser(description="将 Excel 考勤数据导入 MySQL")
    parser.add_argument("--dir", default=EXCEL_DATA_DIR, help="Excel 文件所在目录")
    parser.add_argument("--commit", action="store_true", help="正式写入数据库（默认 dry-run）")
    parser.add_argument("--force", action="store_true", help="强制更新已有学生记录")
    args = parser.parse_args()

    mode = "正式写入" if args.commit else "DRY-RUN（模拟）"
    print(f"模式: {mode}")
    print(f"数据目录: {args.dir}")
    print()

    # Phase 1: 分析 Excel
    print("Phase 1: 分析 Excel 文件...")
    report = scan_and_analyze(args.dir)
    print(f"  扫描到 {report.total_files} 个文件, {report.total_sheets} 个 sheet, {report.total_students} 个学生")
    print()

    if report.errors:
        print("分析阶段存在错误，终止导入:")
        for e in report.errors:
            print(f"  [X] {e}")
        sys.exit(1)

    # 如果不是 --commit 模式，使用纯本地预览（不需要数据库）
    if not args.commit:
        print("Phase 2: 本地预览（无需数据库连接）...")
        result = preview_from_report(report)
        print()
        print(result.summary())
        print("\n提示: 使用 --commit 参数正式写入数据库")
        return

    # Phase 2: 确保表存在
    print("Phase 2: 确保数据库表存在...")
    Base.metadata.create_all(engine)
    print("  OK")
    print()

    # Phase 3: 导入
    print("Phase 3: 执行导入...")
    result = import_from_report(report, commit=True, force=args.force)
    print()
    print(result.summary())

    if result.errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
