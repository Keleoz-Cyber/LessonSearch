import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_service.dart';
import '../../shared/providers.dart';

class SyncTestPage extends ConsumerStatefulWidget {
  const SyncTestPage({super.key});

  @override
  ConsumerState<SyncTestPage> createState() => _SyncTestPageState();
}

class _SyncTestPageState extends ConsumerState<SyncTestPage> {
  List<String> _logs = [];
  int _syncQueueCount = 0;
  int _failedCount = 0;
  int _taskCount = 0;
  int _recordCount = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadLogs();
  }

  Future<void> _loadStats() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final pendingItems = await local.getPendingSyncItems();
      final failedItems = await local.getFailedSyncItems();

      final db = ref.read(databaseProvider);
      final taskCount = await (db.select(db.attendanceTasks)).get();
      final recordCount = await (db.select(db.attendanceRecords)).get();

      setState(() {
        _syncQueueCount = pendingItems.length;
        _failedCount = failedItems.length;
        _taskCount = taskCount.length;
        _recordCount = recordCount.length;
      });
    } catch (e) {
      _addLog('加载统计失败: $e', isError: true);
    }
  }

  Future<void> _loadLogs() async {
    final savedLogs =
        ref.read(sharedPreferencesProvider).getStringList('debug_logs') ?? [];
    setState(() {
      _logs = savedLogs;
    });
  }

  void _addLog(String msg, {bool isError = false}) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final log = '[$timestamp] ${isError ? "❌ " : ""}$msg';
    setState(() {
      _logs.insert(0, log);
      if (_logs.length > 100) _logs.removeLast();
    });
    _saveLogs();
  }

  Future<void> _saveLogs() async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList('debug_logs', _logs);
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      final sync = ref.read(syncServiceProvider);
      await sync.syncNow();
      _addLog('手动同步完成');
      await _loadStats();
    } catch (e) {
      _addLog('同步失败: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _retryFailed() async {
    if (_failedCount == 0) {
      _addLog('没有失败记录');
      return;
    }
    setState(() => _loading = true);
    try {
      final local = ref.read(attendanceLocalDSProvider);
      await local.retryAllFailed();
      _addLog('已重试 $_failedCount 条失败记录');
      await _loadStats();
    } catch (e) {
      _addLog('重试失败: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _clearLogs() async {
    setState(() => _logs.clear());
    await _saveLogs();
  }

  Future<void> _clearSyncQueue() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空同步队列吗？这不会删除本地任务数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final local = ref.read(attendanceLocalDSProvider);
      await local.clearSyncQueue();
      _addLog('已清空同步队列');
      await _loadStats();
    } catch (e) {
      _addLog('清空失败: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('调试工具'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                syncState == SyncState.syncing
                    ? Icons.sync
                    : syncState == SyncState.error
                    ? Icons.sync_problem
                    : Icons.check_circle,
                color: syncState == SyncState.error ? Colors.red : null,
              ),
              tooltip: '同步状态',
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
        children: [
          // 统计卡片
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _StatCard(label: '任务', count: _taskCount, color: Colors.blue),
                const SizedBox(width: 8),
                _StatCard(
                  label: '记录',
                  count: _recordCount,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatCard(
                  label: '待同步',
                  count: _syncQueueCount,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _StatCard(label: '失败', count: _failedCount, color: Colors.red),
              ],
            ),
          ),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _syncNow,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('立即同步'),
                ),
                if (_failedCount > 0)
                  FilledButton.icon(
                    onPressed: _loading ? null : _retryFailed,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('重试失败 ($_failedCount)'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                OutlinedButton(
                  onPressed: _clearSyncQueue,
                  child: const Text('清空队列'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // 日志区域
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('操作日志', style: Theme.of(context).textTheme.titleSmall),
                TextButton(onPressed: _clearLogs, child: const Text('清空')),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text('暂无日志', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isError = log.contains('❌');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError ? Colors.red : null,
                          ),
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

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
