import '../../../../core/network/api_client.dart';
import '../../domain/models.dart';

/// 封装 ApiClient 调用，负责 JSON ↔ 领域模型的转换
class AttendanceRemoteDataSource {
  final ApiClient _api;

  AttendanceRemoteDataSource(this._api);

  // ============================================================
  // 任务
  // ============================================================

  Future<Map<String, dynamic>> createTask(AttendanceTask task) async {
    return await _api.createTask({
      'id': task.id,
      'user_id': task.userId,
      'type': task.type.value,
      'class_ids': task.classIds,
      'selected_grade_id': task.selectedGradeId,
      'selected_major_id': task.selectedMajorId,
    });
  }

  Future<Map<String, dynamic>> updateTask(
    String taskId, {
    TaskStatus? status,
    TaskPhase? phase,
    int? currentClassIndex,
    int? currentStudentIndex,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status.value;
    if (phase != null) body['phase'] = phase.value;
    if (currentClassIndex != null)
      body['current_class_index'] = currentClassIndex;
    if (currentStudentIndex != null)
      body['current_student_index'] = currentStudentIndex;
    return await _api.updateTask(taskId, body);
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    return await _api.getTask(taskId);
  }

  // ============================================================
  // 考勤记录
  // ============================================================

  Future<List<dynamic>> createRecords(
    String taskId,
    List<AttendanceRecord> records,
  ) async {
    final body = records
        .map(
          (r) => {
            'student_id': r.studentId,
            'class_id': r.classId,
            'status': r.status.value,
          },
        )
        .toList();
    return await _api.createRecords(taskId, body);
  }

  Future<Map<String, dynamic>> updateRecord(
    int recordId,
    AttendanceStatus status,
  ) async {
    return await _api.updateRecord(recordId, {'status': status.value});
  }

  Future<Map<String, dynamic>> updateRecordByTaskStudent(
    String taskId,
    int studentId,
    AttendanceStatus status,
  ) async {
    return await _api.updateRecordByTaskStudent(taskId, studentId, {
      'status': status.value,
    });
  }
}
