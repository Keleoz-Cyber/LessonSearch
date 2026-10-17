import 'package:dio/dio.dart';

String responseErrorDetail(dynamic data) {
  if (data is String) {
    final text = data.trim();
    return text.startsWith('<') ? '' : text;
  }
  if (data is Map) {
    return responseErrorDetail(
      data['detail'] ?? data['message'] ?? data['msg'],
    );
  }
  if (data is List) {
    return data.map(responseErrorDetail).where((s) => s.isNotEmpty).join('；');
  }
  return '';
}

String dioErrorMessage(DioException error, {String fallback = '操作失败，请稍后重试'}) {
  final detail = responseErrorDetail(error.response?.data);
  if (detail.isNotEmpty) return detail;
  if (error.response?.statusCode == 429) return '请求过于频繁，请稍后再试';
  if ((error.response?.statusCode ?? 0) >= 500) return '服务暂时不可用，请稍后重试';
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return '连接超时，请检查网络后重试';
  }
  if (error.type == DioExceptionType.connectionError) return '网络连接失败，请稍后重试';
  return fallback;
}
