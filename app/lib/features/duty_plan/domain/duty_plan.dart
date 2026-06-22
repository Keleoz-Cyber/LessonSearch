import 'dart:convert';

/// 节次时间表（固定）
class PeriodSchedule {
  final int period;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const PeriodSchedule({
    required this.period,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get label => '第 $period 节';
  String get startLabel =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get endLabel =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  String get timeRange => '$startLabel - $endLabel';
}

const kPeriodSchedules = <PeriodSchedule>[
  PeriodSchedule(period: 1, startHour: 8, startMinute: 30, endHour: 9, endMinute: 15),
  PeriodSchedule(period: 2, startHour: 9, startMinute: 20, endHour: 10, endMinute: 5),
  PeriodSchedule(period: 3, startHour: 10, startMinute: 25, endHour: 11, endMinute: 10),
  PeriodSchedule(period: 4, startHour: 11, startMinute: 15, endHour: 12, endMinute: 0),
  PeriodSchedule(period: 5, startHour: 14, startMinute: 30, endHour: 15, endMinute: 15),
  PeriodSchedule(period: 6, startHour: 15, startMinute: 20, endHour: 16, endMinute: 5),
  PeriodSchedule(period: 7, startHour: 16, startMinute: 25, endHour: 17, endMinute: 10),
  PeriodSchedule(period: 8, startHour: 17, startMinute: 15, endHour: 18, endMinute: 0),
];

PeriodSchedule periodOf(int period) {
  return kPeriodSchedules.firstWhere((p) => p.period == period);
}

const kWeekdayLabels = <int, String>{
  1: '周一',
  2: '周二',
  3: '周三',
  4: '周四',
  5: '周五',
};

/// 查课计划领域模型
class DutyPlan {
  final String id;
  final int weekNumber;
  final int weekday; // 1-5
  final int period; // 1-8
  final List<String> classIds;
  final String? className; // 显示用班级名缓存
  final String? classroom; // 教室
  final String? remark;
  final int notificationId;
  final bool reminderEnabled;
  final DateTime classStartAt;
  final DateTime createdAt;

  const DutyPlan({
    required this.id,
    required this.weekNumber,
    required this.weekday,
    required this.period,
    required this.classIds,
    this.className,
    this.classroom,
    this.remark,
    required this.notificationId,
    this.reminderEnabled = true,
    required this.classStartAt,
    required this.createdAt,
  });

  DateTime get remindAt =>
      classStartAt.subtract(const Duration(minutes: 15));

  String get weekdayLabel => kWeekdayLabels[weekday] ?? '?';
  String get periodLabel => periodOf(period).label;
  String get timeRange => periodOf(period).timeRange;

  bool get isPast => DateTime.now().isAfter(classStartAt);
  bool get isUpcoming =>
      DateTime.now().isBefore(classStartAt) &&
      classStartAt.difference(DateTime.now()).inDays < 7;

  static String encodeClassIds(List<String> ids) => jsonEncode(ids);
  static List<String> decodeClassIds(String raw) =>
      (jsonDecode(raw) as List).cast<String>();

  /// 通过 weekNumber + weekday + period 计算稳定的 notification id
  /// 范围 1..(N*40)，flutter_local_notifications 要求 int32 范围内
  static int computeNotificationId(int weekNumber, int weekday, int period) {
    return weekNumber * 100 + weekday * 10 + period;
  }

  /// 由 startDate (周一) + weekday + period 计算上课绝对时间
  static DateTime computeClassStartAt({
    required DateTime startDate,
    required int weekday,
    required int period,
  }) {
    final p = periodOf(period);
    final base = DateTime(startDate.year, startDate.month, startDate.day);
    return base
        .add(Duration(days: weekday - 1))
        .add(Duration(hours: p.startHour, minutes: p.startMinute));
  }
}
