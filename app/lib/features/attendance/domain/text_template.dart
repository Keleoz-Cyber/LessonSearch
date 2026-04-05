// 查课汇报文本模板
//
// 可用占位符：
//   {date}         — 日期（如 2026-04-03）
//   {class_names}  — 班级名称（如 计科2401、计科2402）
//   {total}        — 应到人数
//   {present}      — 实到人数
//   {absent}       — 缺勤人数
//   {late}         — 迟到人数
//   {leave}        — 请假人数
//   {other}        — 其他人数
//   {absent_list}  — 缺勤名单（姓名 学号）
//   {late_list}    — 迟到名单（姓名 学号）
//   {leave_list}   — 请假名单（姓名 学号）
//   {other_list}   — 其他名单（姓名 学号 备注）

/// 总群汇报模板（按班级分组）
const defaultGroupReportTemplate = '''
{date} 考勤汇报
{class_reports}
''';

/// 单个班级汇报模板
const classReportTemplate = '''
{class_name}：
应到 {total} 人，实到 {present} 人
{absent_section}
{late_section}
{leave_section}
{other_section}''';

/// 学委汇报模板（按班级分组）
const defaultCommitteeReportTemplate = '''
{date} {class_name} 考勤
应到 {total} 人，实到 {present} 人
缺勤（{absent}人）：{absent_names}
迟到（{late}人）：{late_names}
请假（{leave}人）：{leave_names}
其他（{other}人）：{other_names}
请学委未到的确认下发到场证明，请假发一下假条
''';

/// 考勤统计数据
class AttendanceStats {
  final String date;
  final List<String> classNames;
  final int total;
  final int present;
  final int absent;
  final int late_;
  final int leave;
  final int other;
  final List<StudentRecord> absentStudents;
  final List<StudentRecord> lateStudents;
  final List<StudentRecord> leaveStudents;
  final List<StudentRecord> otherStudents;

  const AttendanceStats({
    required this.date,
    required this.classNames,
    required this.total,
    required this.present,
    required this.absent,
    required this.late_,
    required this.leave,
    required this.other,
    required this.absentStudents,
    required this.lateStudents,
    required this.leaveStudents,
    required this.otherStudents,
  });
}

class StudentRecord {
  final String name;
  final String studentNo;
  final String className;
  final String? remark;

  const StudentRecord({
    required this.name,
    required this.studentNo,
    required this.className,
    this.remark,
  });
}

/// 按班级细分的统计
class ClassStats {
  final String className;
  final int total;
  final int present;
  final int absent;
  final int late_;
  final int leave;
  final int other;
  final List<StudentRecord> absentStudents;
  final List<StudentRecord> lateStudents;
  final List<StudentRecord> leaveStudents;
  final List<StudentRecord> otherStudents;

  const ClassStats({
    required this.className,
    required this.total,
    required this.present,
    required this.absent,
    required this.late_,
    required this.leave,
    required this.other,
    required this.absentStudents,
    required this.lateStudents,
    required this.leaveStudents,
    required this.otherStudents,
  });
}

/// 生成总群汇报文本（按班级分组）
String generateGroupReport(
  List<ClassStats> classStatsList,
  String date, {
  String template = defaultGroupReportTemplate,
}) {
  final classReports = StringBuffer();
  for (var i = 0; i < classStatsList.length; i++) {
    final cs = classStatsList[i];
    final absentSection = cs.absent > 0
        ? '缺勤（${cs.absent}人）：${_formatNames(cs.absentStudents)}'
        : '';
    final lateSection = cs.late_ > 0
        ? '迟到（${cs.late_}人）：${_formatNames(cs.lateStudents)}'
        : '';
    final leaveSection = cs.leave > 0
        ? '请假（${cs.leave}人）：${_formatNames(cs.leaveStudents)}'
        : '';
    final otherSection = cs.other > 0
        ? '其他（${cs.other}人）：${_formatNamesWithRemark(cs.otherStudents)}'
        : '';

    final report = classReportTemplate
        .replaceAll('{class_name}', cs.className)
        .replaceAll('{total}', '${cs.total}')
        .replaceAll('{present}', '${cs.present}')
        .replaceAll('{absent_section}', absentSection)
        .replaceAll('{late_section}', lateSection)
        .replaceAll('{leave_section}', leaveSection)
        .replaceAll('{other_section}', otherSection)
        .trim();

    classReports.writeln(report);
    if (i < classStatsList.length - 1) {
      classReports.writeln();
    }
  }

  return template
      .replaceAll('{date}', date)
      .replaceAll('{class_reports}', classReports.toString().trim())
      .trim();
}

/// 生成学委汇报文本（按班级分组）
String generateCommitteeReport(
  List<ClassStats> classStatsList,
  String date, {
  String template = defaultCommitteeReportTemplate,
}) {
  final buffer = StringBuffer();
  for (final cs in classStatsList) {
    final text = template
        .replaceAll('{date}', date)
        .replaceAll('{class_name}', cs.className)
        .replaceAll('{total}', '${cs.total}')
        .replaceAll('{present}', '${cs.present}')
        .replaceAll('{absent}', '${cs.absent}')
        .replaceAll('{late}', '${cs.late_}')
        .replaceAll('{leave}', '${cs.leave}')
        .replaceAll('{other}', '${cs.other}')
        .replaceAll('{absent_names}', _formatNames(cs.absentStudents))
        .replaceAll('{late_names}', _formatNames(cs.lateStudents))
        .replaceAll('{leave_names}', _formatNames(cs.leaveStudents))
        .replaceAll('{other_names}', _formatNamesWithRemark(cs.otherStudents))
        .trim();
    buffer.writeln(text);
    buffer.writeln();
  }
  return buffer.toString().trim();
}

String _formatNames(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students.map((s) => s.name).join('、');
}

String _formatNamesWithRemark(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students
      .map((s) {
        return s.remark != null ? '${s.name}(${s.remark})' : s.name;
      })
      .join('、');
}
