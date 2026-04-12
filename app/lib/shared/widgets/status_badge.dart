import 'package:flutter/material.dart';

enum AttendanceStatus { present, absent, late, leave, other }

extension AttendanceStatusExtension on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return '到课';
      case AttendanceStatus.absent:
        return '缺勤';
      case AttendanceStatus.late:
        return '迟到';
      case AttendanceStatus.leave:
        return '请假';
      case AttendanceStatus.other:
        return '其他';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.leave:
        return Colors.blue;
      case AttendanceStatus.other:
        return Colors.purple;
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceStatus.present:
        return '到';
      case AttendanceStatus.absent:
        return '缺';
      case AttendanceStatus.late:
        return '迟';
      case AttendanceStatus.leave:
        return '假';
      case AttendanceStatus.other:
        return '他';
    }
  }
}

enum SubmissionStatus { pending, approved, rejected, cancelled }

extension SubmissionStatusExtension on SubmissionStatus {
  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return '待审核';
      case SubmissionStatus.approved:
        return '已通过';
      case SubmissionStatus.rejected:
        return '已拒绝';
      case SubmissionStatus.cancelled:
        return '已撤销';
    }
  }

  Color get color {
    switch (this) {
      case SubmissionStatus.pending:
        return Colors.orange;
      case SubmissionStatus.approved:
        return Colors.green;
      case SubmissionStatus.rejected:
        return Colors.red;
      case SubmissionStatus.cancelled:
        return Colors.grey;
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.isCompact = false,
  });

  factory StatusBadge.fromAttendance(
    AttendanceStatus status, {
    bool isCompact = false,
  }) {
    return StatusBadge(
      label: isCompact ? status.shortLabel : status.label,
      color: status.color,
      isCompact: isCompact,
    );
  }

  factory StatusBadge.fromSubmission(SubmissionStatus status) {
    return StatusBadge(label: status.label, color: status.color);
  }

  factory StatusBadge.pending() =>
      StatusBadge.fromSubmission(SubmissionStatus.pending);
  factory StatusBadge.approved() =>
      StatusBadge.fromSubmission(SubmissionStatus.approved);
  factory StatusBadge.rejected() =>
      StatusBadge.fromSubmission(SubmissionStatus.rejected);
  factory StatusBadge.cancelled() =>
      StatusBadge.fromSubmission(SubmissionStatus.cancelled);

  factory StatusBadge.present({bool isCompact = false}) =>
      StatusBadge.fromAttendance(
        AttendanceStatus.present,
        isCompact: isCompact,
      );
  factory StatusBadge.absent({bool isCompact = false}) =>
      StatusBadge.fromAttendance(AttendanceStatus.absent, isCompact: isCompact);
  factory StatusBadge.late({bool isCompact = false}) =>
      StatusBadge.fromAttendance(AttendanceStatus.late, isCompact: isCompact);
  factory StatusBadge.leave({bool isCompact = false}) =>
      StatusBadge.fromAttendance(AttendanceStatus.leave, isCompact: isCompact);
  factory StatusBadge.other({bool isCompact = false}) =>
      StatusBadge.fromAttendance(AttendanceStatus.other, isCompact: isCompact);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const CountBadge({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  factory CountBadge.late(int count) =>
      CountBadge(label: '迟', count: count, color: Colors.orange);
  factory CountBadge.absent(int count) =>
      CountBadge(label: '缺', count: count, color: Colors.red);
  factory CountBadge.leave(int count) =>
      CountBadge(label: '假', count: count, color: Colors.blue);
  factory CountBadge.other(int count) =>
      CountBadge(label: '他', count: count, color: Colors.grey);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label$count', style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
