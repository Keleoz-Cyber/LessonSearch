import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/attendance/data/local/attendance_local_ds.dart';
import '../logger/logger_service.dart';
import '../../features/attendance/data/remote/attendance_remote_ds.dart';
import '../../features/attendance/domain/models.dart';

/// 同步完成事件
class SyncCompleteEvent {
  final int success;
  final int failed;
  final int skipped;
  final DateTime timestamp;

  SyncCompleteEvent({
    required this.success,
    required this.failed,
    required this.skipped,
  }) : timestamp = DateTime.now();
}

/// 消费 SyncQueue，将本地变更发送到服务端。
class SyncService {
  final AttendanceLocalDataSource _local;
  final AttendanceRemoteDataSource _remote;

  Timer? _timer;
  bool _isSyncing = false;
  bool _needSyncAgain = false; // 标志位：当前同步完成后需要再同步一次
  static const _maxRetries = 5;
  static const _interval = Duration(seconds: 10);

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  
  // 同步进度：current=当前处理到第几个, total=总共需要同步几个
  final ValueNotifier<({int current, int total})?> progress = ValueNotifier(null);
  
  // 使用 StreamController 确保每次同步完成都发送事件（即使结果相同）
  final _syncCompleteController = StreamController<SyncCompleteEvent>.broadcast();
  Stream<SyncCompleteEvent> get onSyncComplete => _syncCompleteController.stream;

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

  Future<({int success, int failed, int skipped})> syncNow() async {
    if (_isSyncing) {
      // 如果正在同步，设置标志位，等待当前同步完成后再执行一次
      _needSyncAgain = true;
      LoggerService.sync('已有同步在进行，等待完成后再同步');
      // 等待当前同步完成
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // 等待完成后，再次检查是否还有未同步项
      return syncNow();
    }
    return processQueueWithStats();
  }

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
      progress.value = (current: 0, total: items.length);
      var successCount = 0;
      var failCount = 0;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        progress.value = (current: i + 1, total: items.length);
        
        try {
          await _processItem(
            item.entityType,
            item.entityId,
            item.action,
            item.payload,
          );
          await _local.markSynced(item.id);
          successCount++;
          LoggerService.sync(
            'OK: ${item.entityType}/${item.action} #${item.entityId}',
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
            LoggerService.sync(
              'SKIP (404): ${item.entityType}/${item.action} #${item.entityId}',
            );
            successCount++;
          } else if (isNetwork) {
            await _local.markSyncFailed(item.id, retryCount: newRetry);
            failCount++;
            LoggerService.sync('网络不可用，稍后重试');
            break;
          } else {
            await _local.markSyncFailed(item.id, retryCount: newRetry);
            failCount++;
            if (newRetry >= _maxRetries) {
              LoggerService.sync(
                'GIVE UP: ${item.entityType}/${item.action} #${item.entityId} ($e)',
                isError: true,
              );
            } else {
              LoggerService.sync(
                'RETRY $newRetry/$_maxRetries: ${item.entityType}/${item.action} #${item.entityId} ($e)',
                isError: true,
              );
            }
          }
        }
      }

      state.value = failCount > 0 ? SyncState.error : SyncState.idle;
      final result = (success: successCount, failed: failCount, skipped: 0);
      
      // 发送同步完成事件（使用 Stream 确保每次都会触发，即使结果相同）
      _syncCompleteController.add(SyncCompleteEvent(
        success: successCount,
        failed: failCount,
        skipped: 0,
      ));
      
      LoggerService.sync('完成: 成功=$successCount 失败=$failCount');
      return result;
    } finally {
      _isSyncing = false;
      // 延迟清除进度，让用户看到 100%
      Future.delayed(const Duration(milliseconds: 500), () {
        progress.value = null;
      });
      
      // 检查是否需要再次同步（因为在同步期间可能有新的 syncNow 调用）
      if (_needSyncAgain) {
        _needSyncAgain = false;
        LoggerService.sync('检测到需要再次同步，启动新一轮同步');
        // 延迟一点再启动，避免立即递归
        Future.delayed(const Duration(milliseconds: 100), () {
          syncNow();
        });
      }
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
      LoggerService.sync('JSON 解析失败: $entityType/$entityId - $e', isError: true);
      rethrow;
    }

    switch (entityType) {
      case 'task':
        await _syncTask(entityId, action, payload);
      case 'record':
        await _syncRecord(entityId, action, payload);
      default:
        LoggerService.sync('未知 entityType: $entityType', isError: true);
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
        final taskId = payload['task_id'] as String?;
        final studentId = payload['student_id'] as int?;
        final status = AttendanceStatus.fromString(payload['status'] as String);

        if (taskId != null && studentId != null) {
          await _remote.updateRecordByTaskStudent(taskId, studentId, status);
        } else {
          final id = int.parse(recordId);
          await _remote.updateRecord(id, status);
        }
    }
  }

  void dispose() {
    stop();
    state.dispose();
    progress.dispose();
    _syncCompleteController.close();
  }
}

enum SyncState { idle, syncing, error }
