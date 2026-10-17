import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/error_message.dart';

class SubmissionService {
  final ApiClient _api;

  SubmissionService(this._api);

  Map<String, dynamic> _semester(int? semesterId) => {
    'semester_id': ?semesterId,
  };

  Future<List<dynamic>> getSemesters() async {
    final res = await _api.dio.get('/week/semesters');
    return res.data as List;
  }

  Future<List<dynamic>> getHistoryWeeks({int? semesterId}) async {
    final res = await _api.dio.get(
      '/submissions/history',
      queryParameters: _semester(semesterId),
    );
    return res.data as List;
  }

  Future<List<dynamic>> getMySubmissions({
    int? weekNumber,
    String? status,
    int? semesterId,
  }) async {
    final params = _semester(semesterId);
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
      final detail = responseErrorDetail(e.response?.data);
      if (detail.isNotEmpty) {
        throw Exception('提交失败: $detail');
      }
      rethrow;
    }
  }

  Future<void> cancelSubmission(int submissionId) async {
    await _api.dio.delete('/submissions/$submissionId');
  }

  Future<List<dynamic>> getPendingSubmissions({
    int? weekNumber,
    int? semesterId,
  }) async {
    final params = _semester(semesterId);
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

  Future<Map<String, dynamic>> getExportStatus(
    int weekNumber, {
    int? semesterId,
  }) async {
    final res = await _api.dio.get(
      '/submissions/export-status/$weekNumber',
      queryParameters: _semester(semesterId),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSummary(
    int weekNumber, {
    int? semesterId,
  }) async {
    final res = await _api.dio.get(
      '/submissions/week-summary/$weekNumber',
      queryParameters: _semester(semesterId),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSubmissionStatus(
    int weekNumber, {
    int? semesterId,
  }) async {
    final res = await _api.dio.get(
      '/duties/week-submissions',
      queryParameters: {'week_number': weekNumber, ..._semester(semesterId)},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubmissionRecords(int submissionId) async {
    final res = await _api.dio.get('/submissions/$submissionId/records');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeekSummaryDetail(
    int weekNumber, {
    int? semesterId,
  }) async {
    final res = await _api.dio.get(
      '/submissions/week-summary-detail/$weekNumber',
      queryParameters: _semester(semesterId),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getReviewedSubmissions({
    int? weekNumber,
    int? semesterId,
  }) async {
    final params = _semester(semesterId);
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
    int? semesterId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      ..._semester(semesterId),
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

  Future<List<int>> exportWeek(int weekNumber, {int? semesterId}) async {
    final response = await _api.dio.get(
      '/submissions/export/$weekNumber',
      queryParameters: _semester(semesterId),
      options: Options(responseType: ResponseType.bytes),
    );
    return (response.data as List).cast<int>();
  }
}
