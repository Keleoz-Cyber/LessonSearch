import '../../../core/network/api_client.dart';

class SubmissionService {
  final ApiClient _api;

  SubmissionService(this._api);

  Future<List<dynamic>> getMySubmissions({
    int? weekNumber,
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (weekNumber != null) params['week_number'] = weekNumber;
    if (status != null) params['status'] = status;
    final res = await _api.dio.get('/submissions', queryParameters: params);
    return res.data as List;
  }

  Future<Map<String, dynamic>> getSubmissionDetail(int submissionId) async {
    final res = await _api.dio.get('/submissions/$submissionId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSubmission({
    required int weekNumber,
    required List<String> taskIds,
  }) async {
    final res = await _api.dio.post(
      '/submissions/',
      data: {'week_number': weekNumber, 'task_ids': taskIds},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelSubmission(int submissionId) async {
    await _api.dio.delete('/submissions/$submissionId');
  }

  Future<List<dynamic>> getPendingSubmissions() async {
    final res = await _api.dio.get('/submissions/pending');
    return res.data as List;
  }

  Future<void> approveSubmission(int submissionId, {String? note}) async {
    await _api.dio.put(
      '/submissions/$submissionId/approve',
      data: {'note': note},
    );
  }

  Future<void> rejectSubmission(int submissionId, String note) async {
    await _api.dio.put(
      '/submissions/$submissionId/reject',
      data: {'note': note},
    );
  }

  Future<Map<String, dynamic>> getExportStatus(int weekNumber) async {
    final res = await _api.dio.get('/submissions/export-status/$weekNumber');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSummary(int weekNumber) async {
    final res = await _api.dio.get('/submissions/week-summary/$weekNumber');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSubmissionStatus(int weekNumber) async {
    final res = await _api.dio.get(
      '/duties/week-submissions',
      queryParameters: {'week_number': weekNumber},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubmissionRecords(int submissionId) async {
    final res = await _api.dio.get('/submissions/$submissionId/records');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSummaryDetail(int weekNumber) async {
    final res = await _api.dio.get(
      '/submissions/week-summary-detail/$weekNumber',
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getReviewedSubmissions({int? weekNumber}) async {
    final params = <String, dynamic>{};
    if (weekNumber != null) params['week_number'] = weekNumber;
    final res = await _api.dio.get(
      '/submissions/reviewed',
      queryParameters: params,
    );
    return res.data as List;
  }
}
