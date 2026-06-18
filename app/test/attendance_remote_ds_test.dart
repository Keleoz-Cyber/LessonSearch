import 'package:flutter_test/flutter_test.dart';
import 'package:lesson_search/features/attendance/data/remote/attendance_remote_ds.dart';
import 'package:lesson_search/features/attendance/domain/models.dart';

void main() {
  test('record create payload preserves remark', () {
    final now = DateTime(2026, 5, 23);
    final record = AttendanceRecord(
      taskId: 'task-1',
      studentId: 12,
      classId: 34,
      status: AttendanceStatus.other,
      remark: '体育课请假',
      createdAt: now,
      updatedAt: now,
    );

    expect(recordToRequestBody(record), {
      'student_id': 12,
      'class_id': 34,
      'status': 'other',
      'remark': '体育课请假',
    });
  });

  test('record update payload preserves remark', () {
    expect(recordUpdateRequestBody(AttendanceStatus.other, remark: '迟到说明'), {
      'status': 'other',
      'remark': '迟到说明',
    });
  });
}
