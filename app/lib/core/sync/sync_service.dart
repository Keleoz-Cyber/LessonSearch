import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../features/attendance/data/local/attendance_local_ds.dart';
import '../../features/attendance/data/remote/attendance_remote_ds.dart';
import '../../features/attendance/domain/models.dart';

/// 消费 SyncQueue，将本地变更发送到服务端。
class SyncService {
  final AttendanceLocalDataSource _local;
  final AttendanceRemoteDataSource _remote;

  Timer? _timer;
  bool _isSyncing = false;
  static const _maxRetries = 5;
  static const _interval = Duration(seconds: 10);

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);

  SyncService(this._local, this._remote);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => processQueueWithStats());
    processQueueWithStats();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() => processQueueWithStats();

  /// 返回同步结果统计
  Future<({int success, int failed, int skipped})>
  processQueueWithStats() async {
    if (_isSyncing) return (success: 0, failed: 0, skipped: 0);
    _isSyncing = true;

    try {
      final items = await _local.getPendingSyncItems();
      if (items.isEmpty) {
        state.value = SyncState.idle;
        return (success: 0, failed: 0, skipped: 0);
      }

      state.value = SyncState.syncing;
      var successCount = 0;
      var failCount = 0;

      for (final item in items) {
        try {
          await _processItem(
            item.entityType,
            item.entityId,
            item.action,
            item.payload,
          );
          await _local.markSynced(item.id);
          successCount++;
          debugPrint(
            '[Sync] OK: ${item.entityType}/${item.action} #${item.entityId}',
          );
        } catch (e) {
          final newRetry = item.retryCount + 1;
          final is404 =
              e.toString().contains('404') ||
              e.toString().contains('任务不存在') ||
              e.toString().contains('记录不存在');
          final isNetwork =
              e.toString().contains('SocketException') ||
              e.toString().contains('Connection refused') ||
              e.toString().contains('timed out');

          if (is404) {
            // 服务端不存在，跳过并标记为已同步
            await _local.markSynced(item.id);
            debugPrint(
              '[Sync] SKIP (404): ${item.entityType}/${item.action} #${item.entityId}',
            );
            successCount++;
          } else if (isNetwork) {
            await _local.markSyncFailed(item.id, retryCount: newRetry);
            failCount++;
            debugPrint('[Sync] 网络不可用，稍后重试');
            break;
          } else {
            await _local.markSyncFailed(item.id, retryCount: newRetry);
            failCount++;
            if (newRetry >= _maxRetries) {
              debugPrint(
                '[Sync] GIVE UP: ${item.entityType}/${item.action} #${item.entityId} ($e)',
              );
            } else {
              debugPrint(
                '[Sync] RETRY $newRetry/$_maxRetries: ${item.entityType}/${item.action} #${item.entityId} ($e)',
              );
            }
          }
        }
      }

      state.value = failCount > 0 ? SyncState.error : SyncState.idle;
      debugPrint('[Sync] 完成: 成功=$successCount 失败=$failCount');
      return (success: successCount, failed: failCount, skipped: 0);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processItem(
    String entityType,
    String entityId,
    String action,
    String? payloadJson,
  ) async {
    Map<String, dynamic> payload;
    try {
      payload = payloadJson != null
          ? jsonDecode(payloadJson) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (e) {
      debugPrint('[Sync] JSON 解析失败: $entityType/$entityId - $e');
      rethrow;
    }

    switch (entityType) {
      case 'task':
        await _syncTask(entityId, action, payload);
      case 'record':
        await _syncRecord(entityId, action, payload);
      default:
        debugPrint('[Sync] 未知 entityType: $entityType');
    }
  }

  Future<void> _syncTask(
    String taskId,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case 'create':
        final task = await _local.getTask(taskId);
        if (task == null) return;
        await _remote.createTask(task);
      case 'update':
        await _remote.updateTask(
          taskId,
          status: payload['status'] != null
              ? TaskStatus.fromString(payload['status'])
              : null,
          phase: payload['phase'] != null
              ? TaskPhase.fromString(payload['phase'])
              : null,
          currentClassIndex: payload['current_class_index'] as int?,
          currentStudentIndex: payload['current_student_index'] as int?,
        );
    }
  }

  Future<void> _syncRecord(
    String recordId,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case 'create':
        final taskId = payload['task_id'] as String;
        final record = AttendanceRecord(
          taskId: taskId,
          studentId: payload['student_id'] as int,
          classId: payload['class_id'] as int,
          status: AttendanceStatus.fromString(payload['status'] as String),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _remote.createRecords(taskId, [record]);
      case 'update':
        final id = int.parse(recordId);
        final status = AttendanceStatus.fromString(payload['status'] as String);
        await _remote.updateRecord(id, status);
    }
  }

  void dispose() {
    stop();
    state.dispose();
  }
}

enum SyncState { idle, syncing, error }
