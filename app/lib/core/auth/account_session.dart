import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../notification/notification_service.dart';

class AccountSessionException implements Exception {
  final String message;
  const AccountSessionException(this.message);
  @override
  String toString() => message;
}

bool _sessionBusy = false;
final List<void Function()> _sessionQueue = [];
Future<T> _serializeSession<T>(Future<T> Function() action) {
  final result = Completer<T>();
  Future<void> run() async {
    try {
      result.complete(await action());
    } catch (error, stack) {
      result.completeError(error, stack);
    } finally {
      if (_sessionQueue.isEmpty) {
        _sessionBusy = false;
      } else {
        _sessionQueue.removeAt(0)();
      }
    }
  }

  void start() {
    unawaited(run());
  }

  if (_sessionBusy) {
    _sessionQueue.add(start);
  } else {
    _sessionBusy = true;
    start();
  }
  return result.future;
}

Future<void> _clearAccountCache(
  ProviderContainer ref,
  NotificationService notifications,
) async {
  await ref.read(databaseProvider).clearUserData();
  await notifications.cancelAll();
  final prefs = ref.read(sharedPreferencesProvider);
  for (final key in prefs.getKeys().toList()) {
    if (key == 'data_version' ||
        key == 'sync_base_version' ||
        key.startsWith('sync_class_version_') ||
        key.startsWith('sync_class_student_ids_')) {
      await prefs.remove(key);
    }
  }
}

void _refreshSessionProviders(ProviderContainer ref) {
  ref.invalidate(authServiceProvider);
  ref.invalidate(isLoggedInProvider);
  ref.invalidate(userEmailProvider);
  ref.invalidate(apiClientProvider);
  ref.invalidate(hasPasswordProvider);
  ref.invalidate(dutyPlansProvider);
  ref.invalidate(upcomingDutyPlansProvider);
  ref.invalidate(rollCallProvider);
  ref.invalidate(nameCheckProvider);
}

/// Authentication is committed only after old-account work can no longer send.
Future<void> finalizeAuthentication(
  WidgetRef widgetRef,
  Map<String, dynamic> response, {
  NotificationService? notifications,
}) async {
  final ref = ProviderScope.containerOf(widgetRef.context, listen: false);
  return _serializeSession(
    () => _finalizeAuthentication(ref, response, notifications),
  );
}

Future<void> _finalizeAuthentication(
  ProviderContainer ref,
  Map<String, dynamic> response,
  NotificationService? notifications,
) async {
  final user = Map<String, dynamic>.from(response['user'] as Map);
  final userId = user['id'] as int;
  final service = ref.read(syncServiceProvider);
  await service.pauseAndDrain();
  final auth = ref.read(authServiceProvider);
  if (auth.userId != userId) {
    final count = await ref.read(databaseProvider).getUnsyncedCount();
    if (count > 0) {
      if (auth.isLoggedIn) service.start();
      throw AccountSessionException(
        '上一个账号还有 $count 项未同步或未结束的任务，请先登录原账号完成处理后再切换。',
      );
    }
    await _clearAccountCache(
      ref,
      notifications ?? ref.read(notificationServiceProvider),
    );
  }
  await auth.saveAuth(
    token: response['token'] as String,
    userId: userId,
    email: user['email'] as String,
    nickname: user['nickname'] as String?,
    realName: user['real_name'] as String?,
    role: user['role'] as String?,
  );
  _refreshSessionProviders(ref);
  ref.read(authExpiredProvider.notifier).state = false;
  await ref.read(attendanceLocalDSProvider).resetAuthFailedSyncItems();
  // The new provider binds queue ownership and credentials to this account.
  ref.read(syncServiceProvider).syncNow();
}

Future<void> logoutCurrentAccount(
  WidgetRef widgetRef, {
  NotificationService? notifications,
}) async {
  final ref = ProviderScope.containerOf(widgetRef.context, listen: false);
  return _serializeSession(() => _logoutCurrentAccount(ref, notifications));
}

Future<void> _logoutCurrentAccount(
  ProviderContainer ref,
  NotificationService? notifications,
) async {
  final service = ref.read(syncServiceProvider);
  await service.pauseAndDrain();
  if (await ref.read(databaseProvider).getUnsyncedCount() > 0) {
    service.start();
    throw const AccountSessionException('仍有未同步或未结束的任务，请先完成处理后退出。');
  }
  await _clearAccountCache(
    ref,
    notifications ?? ref.read(notificationServiceProvider),
  );
  ref.read(authExpiredProvider.notifier).state = false;
  await ref.read(authServiceProvider).clearAuth();
  _refreshSessionProviders(ref);
}
