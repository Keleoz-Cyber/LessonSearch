import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/network/api_client.dart';
import '../core/sync/sync_service.dart';
import '../features/auth/data/auth_service.dart';
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

/// SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('需要在 main.dart 中初始化');
});

/// 认证服务
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(sharedPreferencesProvider));
});

/// 全局 API 客户端
final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(token: authService.token);
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
    ref.watch(sharedPreferencesProvider),
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
final rollCallProvider = StateNotifierProvider<RollCallNotifier, RollCallState>(
  (ref) {
    return RollCallNotifier(
      ref.watch(attendanceRepositoryProvider),
      ref.watch(studentRepositoryProvider),
    );
  },
);

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

/// 主题模式（暗色/亮色/跟随系统）
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeModeNotifier(this._prefs) : super(_loadThemeMode(_prefs));

  static ThemeMode _loadThemeMode(SharedPreferences prefs) {
    final value = prefs.getString(_key);
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final value = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
        ? 'light'
        : 'system';
    _prefs.setString(_key, value);
  }
}
