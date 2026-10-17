import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/attendance/data/local/attendance_local_ds.dart';
import '../../features/attendance/data/remote/attendance_remote_ds.dart';
import '../../features/attendance/domain/models.dart';
import '../database/app_database.dart' as db;
import '../logger/logger_service.dart';

typedef SyncResult = ({int success, int failed, int skipped});

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

/// An outbox row is claimed atomically before sending. Edits made while a row
/// is claimed create a successor; an ACK can therefore never acknowledge them.
class SyncService {
  final AttendanceLocalDataSource _local;
  final AttendanceRemoteDataSource _remote;
  final int? userId;
  final bool Function()? canSync;
  Timer? _timer;
  Future<SyncResult>? _active;
  bool _paused = false;
  bool _disposed = false;
  bool _resourcesDisposed = false;

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  final ValueNotifier<({int current, int total})?> progress = ValueNotifier(
    null,
  );
  final _syncCompleteController =
      StreamController<SyncCompleteEvent>.broadcast();
  Stream<SyncCompleteEvent> get onSyncComplete =>
      _syncCompleteController.stream;

  SyncService(this._local, this._remote, {this.userId, this.canSync});

  bool get _allowed => !_disposed && !_paused && (canSync?.call() ?? true);

  void start() {
    if (_disposed) return;
    _paused = false;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => processQueueWithStats(),
    );
    processQueueWithStats();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Account transitions must wait for the last HTTP response before clearing
  /// or replacing the account's local data and credentials.
  Future<void> pauseAndDrain() async {
    _paused = true;
    stop();
    await _active;
  }

  Future<SyncResult> syncNow() async {
    var success = 0;
    var failed = 0;
    // Drain successor edits too, but do not burn through all retry attempts in
    // one call when a request fails or a user keeps editing continuously.
    for (var pass = 0; pass < 32 && _allowed; pass++) {
      final result = await processQueueWithStats();
      success += result.success;
      failed += result.failed;
      if (result.failed > 0 || (await _local.getPendingSyncItems()).isEmpty) {
        break;
      }
    }
    final remaining = await _local.getSyncIssueCount();
    return (
      success: success,
      failed: failed > remaining ? failed : remaining,
      skipped: 0,
    );
  }

  Future<SyncResult> processQueueWithStats() {
    if (_active != null) return _active!;
    if (!_allowed) return Future.value((success: 0, failed: 0, skipped: 0));
    final future = _processQueue();
    _active = future;
    return future.whenComplete(() {
      _active = null;
      if (_disposed) _disposeResources();
    });
  }

  Future<SyncResult> _processQueue() async {
    var success = 0;
    var failed = 0;
    var claimed = <db.SyncQueueData>[];
    try {
      await _local.repairLegacySyncQueue();
      if (!_allowed) return (success: 0, failed: 0, skipped: 0);
      claimed = await _local.claimPendingSyncItems();
      if (claimed.isEmpty) return (success: 0, failed: 0, skipped: 0);
      if (!_disposed) {
        state.value = SyncState.syncing;
        progress.value = (current: 0, total: claimed.length);
      }
      var index = 0;
      while (index < claimed.length && _allowed) {
        final item = claimed[index];
        if (userId != null && await _local.getSyncItemOwner(item) != userId) {
          await _local.markSyncFailed(item.id, retryCount: 998);
          failed++;
          index++;
          continue;
        }
        final batch = <db.SyncQueueData>[];
        final keys = <String>{};
        for (var j = index; j < claimed.length && batch.length < 50; j++) {
          final candidate = claimed[j];
          if (candidate.entityType != 'record' ||
              candidate.action != 'update') {
            break;
          }
          final p = _payload(candidate);
          final key = '${p['task_id']}/${p['student_id']}';
          if (p['task_id'] is! String ||
              p['student_id'] is! int ||
              p['status'] is! String ||
              !keys.add(key)) {
            break;
          }
          if (userId != null &&
              await _local.getSyncItemOwner(candidate) != userId) {
            break;
          }
          batch.add(candidate);
        }
        if (batch.length >= 2) {
          try {
            final response = await _remote.batchUpdateRecords(
              batch.map((b) => _payload(b)).toList(),
            );
            final ok = (response['success'] as List?) ?? [];
            final errors = (response['failed'] as List?) ?? [];
            for (final b in batch) {
              final p = _payload(b);
              bool matches(dynamic v) =>
                  v['task_id'] == p['task_id'] &&
                  v['student_id'] == p['student_id'];
              if (ok.any(matches)) {
                await _local.markSynced(b.id);
                success++;
              } else {
                final matchesErrors = errors.where(matches);
                final reason = matchesErrors.isEmpty
                    ? '批量响应缺少该记录'
                    : matchesErrors.first['reason'].toString();
                if (reason.contains('记录不存在')) {
                  try {
                    await _restoreMissingRecord(b);
                    await _local.markSynced(b.id);
                    success++;
                  } catch (e) {
                    await _fail(b, e);
                    failed++;
                  }
                } else {
                  await _local.markSyncFailed(
                    b.id,
                    retryCount:
                        reason.contains('已提交') ||
                            reason.contains('不可修改') ||
                            reason.contains('无权')
                        ? 998
                        : b.retryCount + 1,
                  );
                  failed++;
                }
              }
            }
          } catch (e) {
            for (final b in batch) {
              await _fail(b, e);
              failed++;
            }
            if (_shouldStop(e)) break;
          }
          index += batch.length;
        } else {
          try {
            await _processItem(item);
            await _local.markSynced(item.id);
            success++;
          } catch (e) {
            await _fail(item, e);
            failed++;
            if (_shouldStop(e)) break;
          }
          index++;
        }
        if (!_disposed) {
          progress.value = (current: index, total: claimed.length);
        }
      }
    } catch (e, st) {
      failed++;
      LoggerService.error('同步队列处理失败: $e\n$st');
    } finally {
      await _local.releaseClaims(claimed.map((i) => i.id));
      if (!_disposed) {
        final issues = await _local.getSyncIssueCount();
        state.value = failed > 0 || issues > 0
            ? SyncState.error
            : SyncState.idle;
        progress.value = null;
        if (claimed.isNotEmpty || failed > 0) {
          _syncCompleteController.add(
            SyncCompleteEvent(success: success, failed: failed, skipped: 0),
          );
        }
      }
    }
    return (success: success, failed: failed, skipped: 0);
  }

  Map<String, dynamic> _payload(db.SyncQueueData item) => item.payload == null
      ? {}
      : jsonDecode(item.payload!) as Map<String, dynamic>;

  Future<void> _fail(db.SyncQueueData item, Object error) async {
    final code = error is DioException ? error.response?.statusCode : null;
    final retry = code == 401
        ? 999
        : (code == 400 ||
              code == 403 ||
              code == 422 ||
              error is FormatException ||
              error is StateError)
        ? 998
        : item.retryCount + 1;
    await _local.markSyncFailed(item.id, retryCount: retry);
    LoggerService.sync(
      '${item.entityType}/${item.action} #${item.entityId}: $error',
      isError: true,
    );
  }

  bool _shouldStop(Object error) =>
      error is DioException &&
      (error.response?.statusCode == 401 ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout);

  Future<void> _processItem(db.SyncQueueData item) async {
    final p = _payload(item);
    if (item.entityType == 'task') {
      if (item.action == 'create') {
        final task = await _local.getTask(item.entityId);
        if (task == null) throw StateError('待同步任务不存在或不属于当前账号');
        await _remote.createTask(task);
      } else if (item.action == 'update') {
        try {
          await _remote.updateTask(
            item.entityId,
            status: p['status'] == null
                ? null
                : TaskStatus.fromString(p['status']),
            phase: p['phase'] == null ? null : TaskPhase.fromString(p['phase']),
            currentClassIndex: p['current_class_index'] as int?,
            currentStudentIndex: p['current_student_index'] as int?,
          );
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
          final task = await _local.getTask(item.entityId);
          if (task == null) rethrow;
          await _remote.createTask(task);
        }
      } else {
        throw StateError('未知任务操作: ${item.action}');
      }
      return;
    }
    if (item.entityType != 'record') {
      throw StateError('未知同步类型: ${item.entityType}');
    }
    final taskId = p['task_id'] as String?;
    final studentId = p['student_id'] as int?;
    if (taskId == null || studentId == null) throw StateError('记录同步缺少任务/学生标识');
    switch (item.action) {
      case 'create':
        await _remote.createRecords(taskId, [
          AttendanceRecord(
            taskId: taskId,
            studentId: studentId,
            classId: p['class_id'] as int,
            status: AttendanceStatus.fromString(p['status']),
            remark: p['remark'] as String?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);
      case 'update':
        try {
          await _remote.updateRecordByTaskStudent(
            taskId,
            studentId,
            AttendanceStatus.fromString(p['status']),
            remark: p['remark'] as String?,
          );
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
          await _restoreMissingRecord(item);
        }
      case 'delete':
        await _remote.deleteRecordByTaskStudent(taskId, studentId);
      default:
        throw StateError('未知记录操作: ${item.action}');
    }
  }

  Future<void> _restoreMissingRecord(db.SyncQueueData item) async {
    final p = _payload(item);
    final record = await _local.getRecordById(int.parse(item.entityId));
    // A later delete supersedes this update; its own outbox row handles deletion.
    if (record == null) return;
    if (record.taskId != p['task_id'] || record.studentId != p['student_id']) {
      throw StateError('同步记录标识与本地记录不一致');
    }
    await _remote.createRecords(record.taskId, [
      record.copyWith(
        status: AttendanceStatus.fromString(p['status']),
        remark: p['remark'] as String?,
      ),
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    if (_active == null) _disposeResources();
  }

  void _disposeResources() {
    if (_resourcesDisposed) return;
    _resourcesDisposed = true;
    state.dispose();
    progress.dispose();
    _syncCompleteController.close();
  }
}

enum SyncState { idle, syncing, error }
