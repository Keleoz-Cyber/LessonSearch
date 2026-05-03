import 'package:dio/dio.dart';

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
    try {
      final res = await _api.dio.post(
        '/submissions/',
        data: {'week_number': weekNumber, 'task_ids': taskIds},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      if (detail != null) {
        throw Exception('提交失败: $detail');
      }
      rethrow;
    }
  }

  Future<void> cancelSubmission(int submissionId) async {
    await _api.dio.delete('/submissions/$submissionId');
  }

  Future<List<dynamic>> getPendingSubmissions({int? weekNumber}) async {
    final params = <String, dynamic>{};
    if (weekNumber != null) params['week_number'] = weekNumber;
    final res = await _api.dio.get(
      '/submissions/pending',
      queryParameters: params,
    );
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

  Future<Map<String, dynamic>> adminSearchSubmissions({
    int page = 1,
    int pageSize = 20,
    String? status,
    int? weekNumber,
    int? userId,
    String? startDate,
    String? endDate,
    String? keyword,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null) params['status'] = status;
    if (weekNumber != null) params['week_number'] = weekNumber;
    if (userId != null) params['user_id'] = userId;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    final res = await _api.dio.get(
      '/submissions/admin-search',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }
}
