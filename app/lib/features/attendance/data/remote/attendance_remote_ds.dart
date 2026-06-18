import '../../../../core/network/api_client.dart';
import '../../domain/models.dart';

Map<String, dynamic> recordToRequestBody(AttendanceRecord record) {
  final body = {
    'student_id': record.studentId,
    'class_id': record.classId,
    'status': record.status.value,
  };
  final remark = record.remark;
  if (remark != null) {
    body['remark'] = remark;
  }
  return body;
}

Map<String, dynamic> recordUpdateRequestBody(
  AttendanceStatus status, {
  String? remark,
}) {
  final body = {'status': status.value};
  if (remark != null) {
    body['remark'] = remark;
  }
  return body;
}

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
      'status': task.status.value,
      'phase': task.phase.value,
      'current_class_index': task.currentClassIndex,
      'current_student_index': task.currentStudentIndex,
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
    if (currentClassIndex != null) {
      body['current_class_index'] = currentClassIndex;
    }
    if (currentStudentIndex != null) {
      body['current_student_index'] = currentStudentIndex;
    }
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
    final body = records.map(recordToRequestBody).toList();
    return await _api.createRecords(taskId, body);
  }

  Future<Map<String, dynamic>> updateRecord(
    int recordId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    return await _api.updateRecord(
      recordId,
      recordUpdateRequestBody(status, remark: remark),
    );
  }

  Future<Map<String, dynamic>> updateRecordByTaskStudent(
    String taskId,
    int studentId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    return await _api.updateRecordByTaskStudent(
      taskId,
      studentId,
      recordUpdateRequestBody(status, remark: remark),
    );
  }

  Future<Map<String, dynamic>> batchUpdateRecords(
    List<Map<String, dynamic>> items,
  ) async {
    return await _api.batchUpdateRecords(items);
  }
}
