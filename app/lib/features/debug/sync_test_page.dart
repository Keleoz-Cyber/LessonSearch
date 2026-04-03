import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_service.dart';
import '../../shared/providers.dart';
import '../attendance/domain/models.dart';

/// 临时测试页：验证 Flutter → Drift → SyncQueue → SyncService → 服务端 的完整链路
class SyncTestPage extends ConsumerStatefulWidget {
  const SyncTestPage({super.key});

  @override
  ConsumerState<SyncTestPage> createState() => _SyncTestPageState();
}

class _SyncTestPageState extends ConsumerState<SyncTestPage> {
  final _logs = <String>[];
  String? _taskId;

  void _log(String msg) {
    setState(() => _logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg'));
  }

  Future<void> _createTask() async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final task = await repo.createTask(
        type: TaskType.rollCall,
        classIds: [1],
        selectedGradeId: 1,
      );
      _taskId = task.id;
      _log('任务已创建: ${task.id.substring(0, 8)}...');
      _log('已入队 SyncQueue，等待同步...');

      // 立即触发同步
      final sync = ref.read(syncServiceProvider);
      await sync.syncNow();
      _log('同步完成，检查服务端数据库');
    } catch (e) {
      _log('创建失败: $e');
    }
  }

  Future<void> _markStudentPresent() async {
    if (_taskId == null) {
      _log('请先创建任务');
      return;
    }
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final record = await repo.createRecord(
        taskId: _taskId!,
        studentId: 1,
        classId: 1,
        status: AttendanceStatus.present,
      );
      _log('记录已创建: student=1, status=present, localId=${record.id}');

      final sync = ref.read(syncServiceProvider);
      await sync.syncNow();
      _log('同步完成');
    } catch (e) {
      _log('记录失败: $e');
    }
  }

  Future<void> _checkSyncQueue() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final items = await local.getPendingSyncItems();
      _log('待同步队列: ${items.length} 条');
      for (final item in items) {
        _log('  #${item.id} ${item.entityType}/${item.action} retry=${item.retryCount} status=${item.syncStatus}');
      }
    } catch (e) {
      _log('查询失败: $e');
    }
  }

  Future<void> _completeTask() async {
    if (_taskId == null) {
      _log('请先创建任务');
      return;
    }
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final task = await repo.getTask(_taskId!);
      if (task == null) {
        _log('任务不存在');
        return;
      }
      await repo.updateTaskStatus(task, status: TaskStatus.completed, phase: TaskPhase.confirming);
      _log('任务已标记完成');

      final sync = ref.read(syncServiceProvider);
      await sync.syncNow();
      _log('同步完成');
    } catch (e) {
      _log('更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('联调测试'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              syncState == SyncState.syncing
                  ? Icons.sync
                  : syncState == SyncState.error
                      ? Icons.sync_problem
                      : Icons.cloud_done,
              color: syncState == SyncState.error ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _createTask, child: const Text('1. 创建任务')),
                ElevatedButton(onPressed: _markStudentPresent, child: const Text('2. 标记学生到课')),
                ElevatedButton(onPressed: _completeTask, child: const Text('3. 完成任务')),
                OutlinedButton(onPressed: _checkSyncQueue, child: const Text('查看队列')),
                OutlinedButton(
                  onPressed: () => setState(() => _logs.clear()),
                  child: const Text('清空日志'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
