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
  static const _interval = Duration(seconds: 30);

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);

  SyncService(this._local, this._remote);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => processQueue());
    processQueue();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() => processQueue();

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final items = await _local.getPendingSyncItems();
      if (items.isEmpty) {
        state.value = SyncState.idle;
        return;
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
          await _local.markSyncFailed(item.id, retryCount: newRetry);
          failCount++;
          final isNetwork =
              e.toString().contains('SocketException') ||
              e.toString().contains('Connection refused') ||
              e.toString().contains('timed out');
          if (isNetwork) {
            debugPrint('[Sync] 网络不可用，稍后重试');
            break;
          } else if (newRetry >= _maxRetries) {
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

      state.value = failCount > 0 ? SyncState.error : SyncState.idle;
      debugPrint('[Sync] 完成: 成功=$successCount 失败=$failCount');
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
    final payload = payloadJson != null
        ? jsonDecode(payloadJson) as Map<String, dynamic>
        : <String, dynamic>{};

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
