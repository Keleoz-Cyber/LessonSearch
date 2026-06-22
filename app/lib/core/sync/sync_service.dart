import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/attendance/data/local/attendance_local_ds.dart';
import '../database/app_database.dart' as db;
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
  static const _maxRetries = 5;
  static const _interval = Duration(seconds: 10);

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);

  // 同步进度：current=当前处理到第几个, total=总共需要同步几个
  final ValueNotifier<({int current, int total})?> progress = ValueNotifier(
    null,
  );

  // 使用 StreamController 确保每次同步完成都发送事件（即使结果相同）
  final _syncCompleteController =
      StreamController<SyncCompleteEvent>.broadcast();
  Stream<SyncCompleteEvent> get onSyncComplete =>
      _syncCompleteController.stream;

  // 最近一次 processQueueWithStats 的统计结果，用于 syncNow 在"等待中"
  // 路径下能拿到真实的成功/失败计数，而不是错误返回 (0,0,0)。
  ({int success, int failed, int skipped})? _lastResult;

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
      // 已有同步在进行中，等待其完成
      LoggerService.sync('已有同步在进行，等待完成后再同步');
      while (_isSyncing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // 等待结束后：
      // 1. 若队列已干净（无 pending/failed），可安全返回上一次的真实结果，
      //    或在没有上一次结果时返回 (0,0,0)。
      // 2. 若仍存在 pending/failed，触发一次同步并返回其真实结果。
      //    这样能避免"提交前 syncNow 返回 (0,0,0) 让 failed=0 校验通过"的竞态。
      final issueCount = await _local.getSyncIssueCount();
      if (issueCount == 0) {
        return _lastResult ?? (success: 0, failed: 0, skipped: 0);
      }
      // 还有未处理的同步项 → 实际处理一次
      final result = await processQueueWithStats();
      // 如果队列里只剩"已放弃(retry>=5)/认证过期(retry==999)"项，
      // processQueueWithStats 不会处理它们，而是返回 (0,0,0)；
      // 但此时仍存在同步问题，必须把这部分计入 failed，让调用方拒绝放行。
      if (result.success == 0 && result.failed == 0) {
        final remaining = await _local.getSyncIssueCount();
        if (remaining > 0) {
          return (success: 0, failed: remaining, skipped: 0);
        }
      }
      return result;
    }
    return processQueueWithStats();
  }

  /// 返回同步结果统计
  Future<({int success, int failed, int skipped})>
  processQueueWithStats() async {
    if (_isSyncing) return (success: 0, failed: 0, skipped: 0);
    _isSyncing = true;

    try {
      // 修复旧版本升级遗留的 SyncQueue 问题
      final repair = await _local.repairLegacySyncQueue();
      if (repair.values.any((v) => v > 0)) {
        LoggerService.sync(
          'REPAIR: syncing=${repair['syncing']}, '
          'badPayload=${repair['badPayload']}, '
          'incomplete=${repair['incompleteRecord']}, '
          'cleanedSynced=${repair['cleanedSynced']}, '
          'dupRecords=${repair['dupRecords']}',
        );
      }

      final items = await _local.getPendingSyncItems();
      if (items.isEmpty) {
        state.value = SyncState.idle;
        return (success: 0, failed: 0, skipped: 0);
      }

      state.value = SyncState.syncing;
      progress.value = (current: 0, total: items.length);
      var successCount = 0;
      var failCount = 0;

      var i = 0;
      while (i < items.length) {
        final item = items[i];
        progress.value = (current: i + 1, total: items.length);

        // 尝试批量处理连续的 record update（至少 2 条才批量）
        if (item.entityType == 'record' && item.action == 'update') {
          final batchItems = <db.SyncQueueData>[];
          final batchPayloads = <Map<String, dynamic>>[];
          var j = i;

          // 收集连续的 record update（最多 50 条一批）
          while (j < items.length &&
              items[j].entityType == 'record' &&
              items[j].action == 'update' &&
              batchItems.length < 50) {
            final batchItem = items[j];
            final payload = _parsePayload(batchItem.payload);
            final taskId = payload['task_id'] as String?;
            final studentId = payload['student_id'] as int?;
            final status = payload['status'] as String?;

            if (taskId != null && studentId != null && status != null) {
              batchItems.add(batchItem);
              batchPayloads.add({
                'task_id': taskId,
                'student_id': studentId,
                'status': status,
                if (payload['remark'] != null) 'remark': payload['remark'],
              });
            }
            j++;
          }

          // 只有收集到 2 条以上才走批量，否则逐条处理
          if (batchItems.length >= 2) {
            try {
              final result = await _remote.batchUpdateRecords(batchPayloads);
              final successList = (result['success'] as List<dynamic>?) ?? [];
              final failedList = (result['failed'] as List<dynamic>?) ?? [];

              // 成功的标记为已同步
              for (final s in successList) {
                final taskId = s['task_id'] as String;
                final studentId = s['student_id'] as int;
                final matchedItem = _findBatchItem(
                  batchItems,
                  taskId,
                  studentId,
                );
                if (matchedItem == null) {
                  LoggerService.sync(
                    '批量返回项找不到匹配: $taskId/$studentId',
                    isError: true,
                  );
                  continue;
                }
                await _local.markSynced(matchedItem.id);
                successCount++;
              }

              // 失败的根据原因处理
              for (final f in failedList) {
                final taskId = f['task_id'] as String;
                final studentId = f['student_id'] as int;
                final reason = f['reason'] as String;
                final matchedItem = _findBatchItem(
                  batchItems,
                  taskId,
                  studentId,
                );
                if (matchedItem == null) {
                  LoggerService.sync(
                    '批量返回失败项找不到匹配: $taskId/$studentId',
                    isError: true,
                  );
                  continue;
                }

                if (reason.contains('记录不存在') ||
                    reason.contains('已提交审核') ||
                    reason.contains('该任务已放弃') ||
                    reason.contains('不可修改记录')) {
                  // 跳过并标记为已同步
                  await _local.markSynced(matchedItem.id);
                  successCount++;
                  LoggerService.sync(
                    'SKIP (batch): record/update #${matchedItem.entityId} - $reason',
                  );
                } else {
                  final newRetry = matchedItem.retryCount + 1;
                  await _local.markSyncFailed(
                    matchedItem.id,
                    retryCount: newRetry,
                  );
                  failCount++;
                  if (newRetry >= _maxRetries) {
                    LoggerService.sync(
                      'GIVE UP (batch): record/update #${matchedItem.entityId} - $reason',
                      isError: true,
                    );
                  } else {
                    LoggerService.sync(
                      'RETRY $newRetry/$_maxRetries (batch): record/update #${matchedItem.entityId} - $reason',
                      isError: true,
                    );
                  }
                }
              }

              LoggerService.sync(
                'BATCH OK: ${successList.length} 成功, ${failedList.length} 失败',
              );
              progress.value = (current: j, total: items.length);
              i = j; // 跳过已批量处理的 items
              continue; // 继续处理下一个 batch
            } catch (e) {
              final errorStr = e.toString();
              final errorDetail = _extractErrorDetail(e);
              final combinedError = '$errorStr $errorDetail';
              final isNetwork =
                  e is DioException &&
                  (e.type == DioExceptionType.connectionTimeout ||
                      e.type == DioExceptionType.sendTimeout ||
                      e.type == DioExceptionType.receiveTimeout ||
                      e.type == DioExceptionType.connectionError);
              final is401 =
                  combinedError.contains('401') ||
                  combinedError.contains('未登录') ||
                  combinedError.contains('Unauthorized');

              if (is401) {
                // 认证过期，整批标记为失败（需要重新登录）
                for (final batchItem in batchItems) {
                  await _local.markSyncFailed(batchItem.id, retryCount: 999);
                  failCount++;
                }
                LoggerService.sync(
                  'AUTH_EXPIRED (batch): 批量同步中断 — 登录状态已过期，请重新登录后继续同步',
                  isError: true,
                );
                break; // 中断同步循环
              } else if (isNetwork) {
                // 网络错误，全部标记为失败并重试
                for (final batchItem in batchItems) {
                  final newRetry = batchItem.retryCount + 1;
                  await _local.markSyncFailed(
                    batchItem.id,
                    retryCount: newRetry,
                  );
                  failCount++;
                }
                LoggerService.sync(
                  'NETWORK_ERROR (batch): 批量同步中断 — 网络不可用，请检查网络后重试',
                );
                break; // 中断同步循环
              } else {
                // 其他错误，回退到逐条处理当前 batch 的第一个 item
                LoggerService.sync('批量同步失败，回退到逐条处理: $e');
                // i 不变，下面会处理 items[i]
              }
            }
          }
        }

        // 逐条处理（非 record update 或批量失败回退）
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
          final errorStr = e.toString();
          final errorDetail = _extractErrorDetail(e);
          final combinedError = '$errorStr $errorDetail';
          final is404 =
              combinedError.contains('404') ||
              combinedError.contains('任务不存在') ||
              combinedError.contains('记录不存在');
          final isNetwork =
              e is DioException &&
              (e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.sendTimeout ||
                  e.type == DioExceptionType.receiveTimeout ||
                  e.type == DioExceptionType.connectionError);
          final is401 =
              combinedError.contains('401') ||
              combinedError.contains('未登录') ||
              combinedError.contains('Unauthorized');

          if (is401) {
            // 认证过期，标记为失败但不重试（需要重新登录）
            await _local.markSyncFailed(item.id, retryCount: 999);
            failCount++;
            LoggerService.sync(
              'AUTH_EXPIRED: ${item.entityType}/${item.action} #${item.entityId} — 登录状态已过期，请重新登录后继续同步',
              isError: true,
            );
            // 跳过此项，继续同步其他项（不阻塞队列）
            continue;
          } else if (is404) {
            // 服务端不存在，跳过并标记为已同步
            await _local.markSynced(item.id);
            LoggerService.sync(
              'SKIP (404): ${item.entityType}/${item.action} #${item.entityId}',
            );
            successCount++;
          } else if (_isProtected403(e)) {
            // 服务端保护性拒绝（已提交审核/已放弃/不可修改）
            // 不静默标记 synced，而是标记为 failed(retryCount=999)
            // 让用户在同步问题页看到"服务端拒绝"，避免本地/服务端不一致
            await _local.markSyncFailed(item.id, retryCount: 999);
            failCount++;
            LoggerService.sync(
              'REJECTED (403): ${item.entityType}/${item.action} #${item.entityId} - $errorDetail — 服务端拒绝修改，请在同步问题中查看',
              isError: true,
            );
          } else if (isNetwork) {
            await _local.markSyncFailed(item.id, retryCount: newRetry);
            failCount++;
            LoggerService.sync(
              'NETWORK_ERROR: ${item.entityType}/${item.action} #${item.entityId} — 网络不可用，请检查网络后重试',
            );
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

        i++;
      }

      state.value = failCount > 0 ? SyncState.error : SyncState.idle;
      final result = (success: successCount, failed: failCount, skipped: 0);
      _lastResult = result;

      // 发送同步完成事件（使用 Stream 确保每次都会触发，即使结果相同）
      _syncCompleteController.add(
        SyncCompleteEvent(success: successCount, failed: failCount, skipped: 0),
      );

      LoggerService.sync('完成: 成功=$successCount 失败=$failCount');
      return result;
    } finally {
      _isSyncing = false;
      // 延迟清除进度，让用户看到 100%
      Future.delayed(const Duration(milliseconds: 500), () {
        progress.value = null;
      });
    }
  }

  Map<String, dynamic> _parsePayload(String? payloadJson) {
    try {
      return payloadJson != null
          ? jsonDecode(payloadJson) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (e) {
      LoggerService.sync('JSON 解析失败: $payloadJson - $e', isError: true);
      return <String, dynamic>{};
    }
  }

  /// 提取错误 detail 字段，兼容 DioException / 其他异常
  String _extractErrorDetail(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (data is String) {
        return data;
      }
      if (data is List && data.isNotEmpty) {
        return data.first.toString();
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  /// 判断是否是服务端保护性 403（已提交审核/已放弃/不可修改）
  /// 这类 403 是合理的，客户端应跳过而非重试
  bool _isProtected403(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode != 403) return false;
      final detail = _extractErrorDetail(e);
      // 明确的权限拒绝不跳过
      if (detail.contains('无权修改') || detail.contains('无权限')) {
        return false;
      }
      return detail.contains('该记录已提交审核') ||
          detail.contains('已提交审核') ||
          detail.contains('不可修改。如需修改，请先撤回提交') ||
          detail.contains('该任务已放弃') ||
          detail.contains('不可修改记录');
    }

    final s = e.toString();
    if (!s.contains('403')) return false;
    if (s.contains('无权修改') || s.contains('无权限')) return false;
    return s.contains('该记录已提交审核') ||
        s.contains('已提交审核') ||
        s.contains('不可修改。如需修改，请先撤回提交') ||
        s.contains('该任务已放弃') ||
        s.contains('不可修改记录');
  }

  /// 在 batchItems 中查找匹配 task_id + student_id 的 SyncQueueData
  db.SyncQueueData? _findBatchItem(
    List<db.SyncQueueData> batchItems,
    String taskId,
    int studentId,
  ) {
    for (final batchItem in batchItems) {
      final p = _parsePayload(batchItem.payload);
      if (p['task_id'] == taskId && p['student_id'] == studentId) {
        return batchItem;
      }
    }
    return null;
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
      LoggerService.sync(
        'JSON 解析失败: $entityType/$entityId - $e',
        isError: true,
      );
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
          remark: payload['remark'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _remote.createRecords(taskId, [record]);
      case 'update':
        final taskId = payload['task_id'] as String?;
        final studentId = payload['student_id'] as int?;
        final status = AttendanceStatus.fromString(payload['status'] as String);
        final remark = payload['remark'] as String?;

        if (taskId != null && studentId != null) {
          await _remote.updateRecordByTaskStudent(
            taskId,
            studentId,
            status,
            remark: remark,
          );
        } else {
          final id = int.parse(recordId);
          await _remote.updateRecord(id, status, remark: remark);
        }
      case 'delete':
        // 服务端无 delete record API。
        // 点名撤销（prevStudent）的 delete 会被后续的 create/update 覆盖，
        // 或者 task 完成时服务端会重新拉取完整记录列表。
        // 直接跳过，避免 sync 队列无限堆积 delete 项。
        LoggerService.sync(
          'SKIP (delete): record #$recordId — 服务端无 delete API，跳过同步',
        );
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
