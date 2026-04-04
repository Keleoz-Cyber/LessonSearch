import 'package:dio/dio.dart';

class ApiClient {
  static const String defaultBaseUrl = 'https://api.keleoz.cn/api';

  late final Dio dio;
  String? _token;

  ApiClient({String? baseUrl, String? token}) {
    _token = token;
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            _token = null;
          }
          handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;

  // === 认证 ===

  Future<void> sendVerificationCode(String email) async {
    await dio.post('/auth/send-code', data: {'email': email});
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String code,
    required String invitationCode,
  }) async {
    final res = await dio.post(
      '/auth/login',
      data: {'email': email, 'code': code, 'invitation_code': invitationCode},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await dio.get('/auth/me');
    return res.data as Map<String, dynamic>;
  }

  // 年级
  Future<List<dynamic>> getGrades() async {
    final res = await dio.get('/grades');
    return res.data as List;
  }

  // 专业
  Future<List<dynamic>> getMajors() async {
    final res = await dio.get('/majors');
    return res.data as List;
  }

  // 班级（支持筛选）
  Future<List<dynamic>> getClasses({int? gradeId, int? majorId}) async {
    final params = <String, dynamic>{};
    if (gradeId != null) params['grade_id'] = gradeId;
    if (majorId != null) params['major_id'] = majorId;
    final res = await dio.get('/classes', queryParameters: params);
    return res.data as List;
  }

  // 按班级查学生
  Future<List<dynamic>> getStudentsByClass(int classId) async {
    final res = await dio.get('/students/by-class/$classId');
    return res.data as List;
  }

  // === 任务 ===

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    final res = await dio.post('/tasks', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTask(String taskId) async {
    final res = await dio.get('/tasks/$taskId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTask(
    String taskId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.put('/tasks/$taskId', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final res = await dio.get('/tasks', queryParameters: params);
    return res.data as List;
  }

  // === 考勤记录 ===

  Future<List<dynamic>> createRecords(
    String taskId,
    List<Map<String, dynamic>> records,
  ) async {
    final res = await dio.post('/tasks/$taskId/records', data: records);
    return res.data as List;
  }

  Future<List<dynamic>> getRecords(String taskId) async {
    final res = await dio.get('/tasks/$taskId/records');
    return res.data as List;
  }

  Future<Map<String, dynamic>> updateRecord(
    int recordId,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.put('/records/$recordId', data: body);
    return res.data as Map<String, dynamic>;
  }
}
