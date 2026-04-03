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

/// 总群汇报模板
const defaultGroupReportTemplate = '''
{date} 考勤汇报
班级：{class_names}
应到：{total}人，实到：{present}人
缺勤：{absent}人，迟到：{late}人，请假：{leave}人，其他：{other}人
---
缺勤名单：
{absent_list}
迟到名单：
{late_list}
请假名单：
{leave_list}
其他：
{other_list}
''';

/// 学委汇报模板（按班级分组）
const defaultCommitteeReportTemplate = '''
{date} {class_name} 考勤
应到 {total} 人，实到 {present} 人
缺勤（{absent}人）：{absent_names}
迟到（{late}人）：{late_names}
请假（{leave}人）：{leave_names}
其他（{other}人）：{other_names}
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

/// 生成总群汇报文本
String generateGroupReport(AttendanceStats stats, {String template = defaultGroupReportTemplate}) {
  return template
      .replaceAll('{date}', stats.date)
      .replaceAll('{class_names}', stats.classNames.join('、'))
      .replaceAll('{total}', '${stats.total}')
      .replaceAll('{present}', '${stats.present}')
      .replaceAll('{absent}', '${stats.absent}')
      .replaceAll('{late}', '${stats.late_}')
      .replaceAll('{leave}', '${stats.leave}')
      .replaceAll('{other}', '${stats.other}')
      .replaceAll('{absent_list}', _formatStudentList(stats.absentStudents))
      .replaceAll('{late_list}', _formatStudentList(stats.lateStudents))
      .replaceAll('{leave_list}', _formatStudentList(stats.leaveStudents))
      .replaceAll('{other_list}', _formatStudentListWithRemark(stats.otherStudents))
      .trim();
}

/// 生成学委汇报文本（按班级分组）
String generateCommitteeReport(List<ClassStats> classStatsList, String date,
    {String template = defaultCommitteeReportTemplate}) {
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

String _formatStudentList(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students.map((s) => '${s.name}（${s.studentNo}）').join('\n');
}

String _formatStudentListWithRemark(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students.map((s) {
    final remarkStr = s.remark != null ? ' - ${s.remark}' : '';
    return '${s.name}（${s.studentNo}）$remarkStr';
  }).join('\n');
}

String _formatNames(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students.map((s) => s.name).join('、');
}

String _formatNamesWithRemark(List<StudentRecord> students) {
  if (students.isEmpty) return '无';
  return students.map((s) {
    return s.remark != null ? '${s.name}(${s.remark})' : s.name;
  }).join('、');
}
