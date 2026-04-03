import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/network/api_client.dart';
import '../core/sync/sync_service.dart';
import '../features/attendance/application/roll_call_notifier.dart';
import '../features/attendance/application/name_check_notifier.dart';
import '../features/records/data/records_repository.dart';
import '../features/attendance/data/local/attendance_local_ds.dart';
import '../features/attendance/data/remote/attendance_remote_ds.dart';
import '../features/attendance/data/attendance_repository.dart';
import '../features/student/data/student_repository.dart';

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

/// 本地数据源
final attendanceLocalDSProvider = Provider<AttendanceLocalDataSource>((ref) {
  return AttendanceLocalDataSource(ref.watch(databaseProvider));
});

/// 远程数据源
final attendanceRemoteDSProvider = Provider<AttendanceRemoteDataSource>((ref) {
  return AttendanceRemoteDataSource(ref.watch(apiClientProvider));
});

/// 考勤任务仓库
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(attendanceLocalDSProvider),
    ref.watch(attendanceRemoteDSProvider),
  );
});

/// 学生数据仓库
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
  );
});

/// 同步服务
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.watch(attendanceLocalDSProvider),
    ref.watch(attendanceRemoteDSProvider),
  );
  service.start();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 同步状态（供 UI 监听）
final syncStateProvider = Provider<SyncState>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.state.value;
});

/// 点名流程状态管理
final rollCallProvider =
    StateNotifierProvider<RollCallNotifier, RollCallState>((ref) {
  return RollCallNotifier(
    ref.watch(attendanceRepositoryProvider),
    ref.watch(studentRepositoryProvider),
  );
});

/// 记名流程状态管理
final nameCheckProvider =
    StateNotifierProvider<NameCheckNotifier, NameCheckState>((ref) {
  return NameCheckNotifier(
    ref.watch(attendanceRepositoryProvider),
    ref.watch(studentRepositoryProvider),
  );
});

/// 查课记录仓库
final recordsRepositoryProvider = Provider<RecordsRepository>((ref) {
  return RecordsRepository(ref.watch(databaseProvider));
});
