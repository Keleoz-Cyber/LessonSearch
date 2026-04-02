import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/network/api_client.dart';

/// 全局数据库实例
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 全局 API 客户端
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
