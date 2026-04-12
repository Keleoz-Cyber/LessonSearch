import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/sync/sync_service.dart';
import '../../shared/providers.dart';
import '../../features/extension/data/submission_service.dart';

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

  int _currentWeek = 0;
  String _weekStartDate = '';
  String _weekEndDate = '';
  int _weekSubmissionCount = 0;
  int _historyWeekCount = 0;
  bool _weekTestLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadLogs();
    _loadWeekTest();
  }

  Future<void> _loadWeekTest() async {
    try {
      final api = ref.read(apiClientProvider);

      final weekResponse = await api.dio.get('/week/current');
      final weekData = weekResponse.data;
      final weekNumber = weekData['week_number'] as int;
      final startDate = weekData['start_date'] as String;
      final endDate = weekData['end_date'] as String;

      final submissionResponse = await api.dio.get(
        '/submissions/',
        queryParameters: {'week_number': weekNumber},
      );
      final submissions = submissionResponse.data as List;

      final historyResponse = await api.dio.get('/submissions/history');
      final historyWeeks = historyResponse.data as List;

      setState(() {
        _currentWeek = weekNumber;
        _weekStartDate = startDate;
        _weekEndDate = endDate;
        _weekSubmissionCount = submissions.length;
        _historyWeekCount = historyWeeks.length;
      });

      _addLog('当前第$weekNumber周 ($startDate ~ $endDate)');
    } catch (e) {
      _addLog('加载周次数据失败: $e', isError: true);
    }
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
      final result = await sync.processQueueWithStats();
      if (result.success > 0 || result.failed > 0) {
        _addLog('同步完成: 成功 ${result.success}，失败 ${result.failed}');
      } else {
        _addLog('无待同步数据');
      }
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

  Future<void> _testWeekReset() async {
    setState(() => _weekTestLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      final weekResponse = await api.dio.get('/week/current');
      final weekData = weekResponse.data;
      final weekNumber = weekData['week_number'] as int;
      final startDate = weekData['start_date'] as String;

      final startDateTime = DateTime.parse(startDate);
      final now = DateTime.now();

      final daysUntilMonday = (7 - now.weekday) % 7;
      final nextMonday = now.add(Duration(days: daysUntilMonday));
      final nextMondayZero = DateTime(
        nextMonday.year,
        nextMonday.month,
        nextMonday.day,
        0,
        0,
        0,
      );

      final secondsUntilReset = nextMondayZero.difference(now).inSeconds;
      final hoursUntilReset = secondsUntilReset / 3600;

      _addLog('=== 周次重置测试 ===');
      _addLog('当前: 第$weekNumber周');
      _addLog('周期: $startDate ~ ${weekData['end_date']}');
      _addLog('下次重置: ${nextMondayZero.toString().substring(0, 16)}');
      _addLog('距离重置: ${hoursUntilReset.toStringAsFixed(1)}小时');

      if (daysUntilMonday == 0 && now.hour < 24) {
        _addLog('⚠️ 今天是周一，即将重置！');
      }

      final submissionResponse = await api.dio.get(
        '/submissions/',
        queryParameters: {'week_number': weekNumber},
      );
      final submissions = submissionResponse.data as List;
      final pendingCount = submissions
          .where((s) => s['status'] == 'pending')
          .length;
      final approvedCount = submissions
          .where((s) => s['status'] == 'approved')
          .length;

      _addLog(
        '本周提交: ${submissions.length}条 (待审$pendingCount, 已过$approvedCount)',
      );

      final historyResponse = await api.dio.get('/submissions/history');
      final historyWeeks = (historyResponse.data as List)
          .map((w) => w['week_number'])
          .toList();
      _addLog('历史周次: ${historyWeeks.join(", ")}');

      _addLog('结论: 周一零点后，本周提交会变成历史周次');
      _addLog('新周次开始，成员可以提交新一周的名单');

      await _loadWeekTest();
    } catch (e) {
      _addLog('测试失败: $e', isError: true);
    } finally {
      setState(() => _weekTestLoading = false);
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

          // 周次测试卡片
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '周次测试',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '当前: 第${_currentWeek}周 (${_weekStartDate} ~ $_weekEndDate)',
                    ),
                    const SizedBox(height: 4),
                    Text('本周提交: ${_weekSubmissionCount}条'),
                    const SizedBox(height: 4),
                    Text('历史周次: ${_historyWeekCount}个'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _weekTestLoading ? null : _testWeekReset,
                      icon: const Icon(Icons.science, size: 18),
                      label: const Text('测试周次重置'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
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
