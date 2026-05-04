import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/database/app_database.dart';
import '../core/feedback/feedback_service.dart';
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

/// 登录状态（响应式）
final isLoggedInProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.isLoggedIn;
});

/// 用户邮箱（响应式）
final userEmailProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.userEmail;
});

/// 是否已设置密码
/// 注意：异常会向上传播，UI 层需处理 error 状态
/// - 401/token 过期：提示重新登录，跳转登录页
/// - 网络错误/500/超时：显示"加载失败，点击重试"，点击后 invalidate 重新请求
final hasPasswordProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(apiClientProvider);
  final user = await api.getCurrentUser();
  return user['has_password'] == true;
});

/// 反馈服务（振动/音效）
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(ref.watch(sharedPreferencesProvider));
});

/// 振动开关（响应式）
final vibrationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(feedbackServiceProvider).vibrationEnabled;
});

/// 音效开关（响应式）
final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(feedbackServiceProvider).soundEnabled;
});

/// 认证过期事件（401 时触发，供 UI 监听）
final authExpiredProvider = StateProvider<bool>((ref) => false);

/// 全局 API 客户端
final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(
    token: authService.token,
    onAuthExpired: () {
      // 只清除 token，保留 userId 等用户信息
      // 避免清空本地数据库，让用户重新登录后继续同步
      authService.clearTokenOnly();
      ref.read(authExpiredProvider.notifier).state = true;
      ref.invalidate(authServiceProvider);
      ref.invalidate(isLoggedInProvider);
    },
    onTokenRefreshed: (newToken) {
      authService.updateToken(newToken);
      ref.read(authExpiredProvider.notifier).state = false;
    },
  );
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

/// 待同步记录数量（实时）
/// 包含：pending、failed(retry < 5)、auth_failed(retry == 999)
final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  
  // 获取所有记录，然后在 Dart 中过滤
  Future<int> countPending() async {
    final all = await db.select(db.syncQueue).get();
    return all.where((s) {
      if (s.syncStatus == 'pending') return true;
      if (s.syncStatus == 'failed') {
        // 普通失败（可重试）或认证过期失败（需重新登录后重试）
        if (s.retryCount < 5 || s.retryCount == 999) return true;
      }
      return false;
    }).length;
  }
  
  // 初始查询
  yield await countPending();
  
  // 定时刷新（每2秒检查一次）
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await countPending();
  }
});

/// 同步问题数量（实时）
/// 包含：pending + failed（所有 failed，包括 retryCount >= 5 和 999）
final syncIssueCountProvider = StreamProvider<int>((ref) async* {
  final db = ref.watch(databaseProvider);
  
  Future<int> countIssues() async {
    final all = await db.select(db.syncQueue).get();
    return all.where((s) =>
      s.syncStatus == 'pending' || s.syncStatus == 'failed'
    ).length;
  }
  
  yield await countIssues();
  
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await countIssues();
  }
});

/// 是否存在 syncStatus == 'failed' 的记录（实时）
final hasSyncFailedProvider = StreamProvider<bool>((ref) async* {
  final db = ref.watch(databaseProvider);
  
  Future<bool> checkFailed() async {
    final all = await db.select(db.syncQueue).get();
    return all.any((s) => s.syncStatus == 'failed');
  }
  
  yield await checkFailed();
  
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await checkFailed();
  }
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
  return RecordsRepository(
    ref.watch(databaseProvider),
    ref.watch(attendanceLocalDSProvider),
  );
});

/// 主题模式（暗色/亮色/跟随系统）
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

/// 自动同步开关
final autoSyncProvider = StateNotifierProvider<AutoSyncNotifier, bool>((ref) {
  return AutoSyncNotifier(ref.watch(sharedPreferencesProvider));
});

class AutoSyncNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'auto_sync_enabled';

  AutoSyncNotifier(this._prefs) : super(_prefs.getBool(_key) ?? true);

  void setAutoSync(bool enabled) {
    state = enabled;
    _prefs.setBool(_key, enabled);
  }
}

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
