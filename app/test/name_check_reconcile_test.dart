import 'package:flutter_test/flutter_test.dart';
import 'package:lesson_search/features/attendance/application/name_check_notifier.dart';
import 'package:lesson_search/features/attendance/domain/models.dart';

void main() {
  test('reconcile keeps status by studentId and follows active roster', () {
    final current = [
      StudentWithStatus(
        student: const StudentInfo(
          id: 1,
          name: 'Old Name',
          studentNo: '001',
          classId: 10,
        ),
        status: AttendanceStatus.absent,
        remark: 'sick',
        recordId: 101,
      ),
      StudentWithStatus(
        student: const StudentInfo(
          id: 2,
          name: 'Deleted',
          studentNo: '002',
          classId: 10,
        ),
        status: AttendanceStatus.leave,
        recordId: 102,
      ),
    ];

    final activeRoster = [
      const StudentInfo(
        id: 1,
        name: 'New Name',
        studentNo: '001A',
        classId: 10,
      ),
      const StudentInfo(id: 3, name: 'Added', studentNo: '003', classId: 10),
    ];

    final reconciled = reconcileStudentsWithRoster(current, activeRoster);

    expect(reconciled.map((s) => s.student.id), [1, 3]);
    expect(reconciled[0].student.name, 'New Name');
    expect(reconciled[0].student.studentNo, '001A');
    expect(reconciled[0].status, AttendanceStatus.absent);
    expect(reconciled[0].remark, 'sick');
    expect(reconciled[0].recordId, 101);
    expect(reconciled[1].status, AttendanceStatus.pending);
    expect(reconciled[1].recordId, isNull);
  });
}
