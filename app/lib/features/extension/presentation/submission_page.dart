import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/logger/logger_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/toast.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/submission_service.dart';
import '../../attendance/domain/models.dart';

final currentWeekProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/week/current');
  return res.data as Map<String, dynamic>;
});

final myDutyProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.dio.get('/duties/my');
    final data = res.data as Map<String, dynamic>;
    return {'has_duty': true, ...data};
  } on DioException catch (e) {
    // 404 表示没有职务，其他错误（网络/超时等）抛出
    if (e.response?.statusCode == 404) {
      return {'has_duty': false};
    }
    rethrow;
  }
});

final submittedTaskIdsProvider = FutureProvider<Set<String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.dio.get('/submissions/submitted-task-ids');
    final ids = res.data['task_ids'] as List;
    return ids.map((id) => id.toString()).toSet();
  } catch (e) {
    return {};
  }
});

final mySubmissionsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(submissionServiceProvider).getMySubmissions();
});

final weekNameCheckTasksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      weekNumber,
    ) async {
      final repo = ref.watch(attendanceRepositoryProvider);
      final studentRepo = ref.watch(studentRepositoryProvider);
      final submittedIds = await ref.watch(submittedTaskIdsProvider.future);
      final weekData = await ref.watch(currentWeekProvider.future);

      // 服务端返回的是纯日期（YYYY-MM-DD），DateTime.parse 解析后是
      // 本地时间 00:00。包含整周（周一 00:00 起，含周一到周日全部时间）。
      final startDate = DateTime.parse(weekData['start_date'] as String);
      final endDate = DateTime.parse(weekData['end_date'] as String);
      final weekEnd = endDate.add(const Duration(days: 1));

      final tasks = await repo.getCompletedNameCheckTasks();

      // 用 !isBefore(startDate) 避免边界遗漏：周一 00:00:00.000 创建的任务
      // 应当属于本周（原代码 isAfter 是严格大于会漏掉这个边界）。
      final weekTasks = tasks
          .where(
            (t) =>
                !t.createdAt.isBefore(startDate) &&
                t.createdAt.isBefore(weekEnd) &&
                !submittedIds.contains(t.id),
          )
          .toList();

      final result = <Map<String, dynamic>>[];
      for (final task in weekTasks) {
        final classNames = await studentRepo.getClassNames(task.classIds);
        result.add({
          'id': task.id,
          'class_ids': task.classIds,
          'class_names': classNames,
          'created_at': task.createdAt.toIso8601String(),
          'record_count': 0,
        });

        final records = await repo.getRecordsByTask(task.id);
        result.last['record_count'] = records.length;
      }

      return result;
    });

final adminsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/user/admins');
  return res.data as List;
});

final submissionServiceProvider = Provider<SubmissionService>((ref) {
  return SubmissionService(ref.watch(apiClientProvider));
});

class SubmissionPage extends ConsumerStatefulWidget {
  const SubmissionPage({super.key});

  @override
  ConsumerState<SubmissionPage> createState() => _SubmissionPageState();
}

class _SubmissionPageState extends ConsumerState<SubmissionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _selectedTaskIds = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 进入页面时强制同步并刷新职务状态
    Future.microtask(() {
      ref.read(syncServiceProvider).syncNow();
      ref.invalidate(myDutyProvider);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && mounted) {
      ref.invalidate(weekNameCheckTasksProvider);
      ref.invalidate(submittedTaskIdsProvider);
    } else if (_tabController.index == 1 && mounted) {
      ref.invalidate(mySubmissionsProvider);
    }
  }

  Future<void> _submit(int weekNumber) async {
    if (_selectedTaskIds.isEmpty) {
      Toast.show(context, '请选择要提交的任务');
      return;
    }

    setState(() => _loading = true);

    // 提交前强制同步，确保本地编辑已同步到服务端
    // 同步失败则阻止提交，避免数据不一致
    try {
      final syncService = ref.read(syncServiceProvider);
      
      // 先等待当前同步完成
      var result = await syncService.syncNow();
      if (result.failed > 0) {
        setState(() => _loading = false);
        Toast.show(context, '同步失败 ${result.failed} 项，请检查网络后重试');
        return;
      }
      
      // 最终保险检查：只要存在 pending 或 failed，都阻止提交
      final localDS = ref.read(attendanceLocalDSProvider);
      final issueCount = await localDS.getSyncIssueCount();
      if (issueCount > 0) {
        setState(() => _loading = false);
        Toast.show(context, '有 $issueCount 条同步问题未处理，请先到同步问题详情处理');
        return;
      }
      
      LoggerService.sync('提交前同步完成: 所有记录已同步到服务端');

      // 再次校验：选中的任务是否仍然存在、completed、且未删除
      final repo = ref.read(attendanceRepositoryProvider);
      final invalidTasks = <String>[];
      for (final taskId in _selectedTaskIds) {
        final task = await repo.getTask(taskId);
        if (task == null || task.status != TaskStatus.completed) {
          invalidTasks.add(taskId);
        }
      }
      if (invalidTasks.isNotEmpty) {
        setState(() => _loading = false);
        Toast.show(context, '${invalidTasks.length} 个任务已被删除或状态异常，请重新选择');
        // 刷新任务列表，移除无效选中
        setState(() {
          _selectedTaskIds.removeWhere((id) => invalidTasks.contains(id));
        });
        ref.invalidate(weekNameCheckTasksProvider(weekNumber));
        return;
      }

      // 校验服务端任务状态：本地 completed 但服务端不是 completed 时，主动修复
      final remoteDS = ref.read(attendanceRemoteDSProvider);
      final fixFailedTasks = <String>[];
      for (final taskId in _selectedTaskIds) {
        final localTask = await repo.getTask(taskId);
        if (localTask != null && localTask.status == TaskStatus.completed) {
          try {
            final remoteTask = await remoteDS.getTask(taskId);
            final remoteStatus = remoteTask['status'] as String?;
            if (remoteStatus != 'completed') {
              LoggerService.sync(
                '提交前修复任务状态: $taskId 服务端 $remoteStatus → completed',
              );
              await remoteDS.updateTask(
                taskId,
                status: TaskStatus.completed,
              );
            }
          } catch (e) {
            LoggerService.sync(
              '提交前修复任务状态失败: $taskId - $e',
              isError: true,
            );
            fixFailedTasks.add(taskId);
          }
        }
      }
      if (fixFailedTasks.isNotEmpty) {
        setState(() => _loading = false);
        Toast.show(
          context,
          '任务状态尚未同步完成，请先同步后再提交',
        );
        return;
      }
    } catch (e) {
      setState(() => _loading = false);
      LoggerService.sync('同步失败: $e', isError: true);
      Toast.show(context, '同步失败，请检查网络后重试');
      return;
    }

    // 获取所有选中任务的记录数据，用于确认对话框显示
    final tasksConfirmData = <Map<String, dynamic>>[];
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);

      for (final taskId in _selectedTaskIds) {
        final task = await repo.getTask(taskId);
        if (task == null) continue;

        final records = await repo.getRecordsByTask(taskId);
        final classNames = await studentRepo.getClassNames(task.classIds);

        final total = records.length;
        final present = records.where((r) => r.status == AttendanceStatus.present).length;
        final absent = records.where((r) => r.status == AttendanceStatus.absent).length;
        final late = records.where((r) => r.status == AttendanceStatus.late_).length;
        final leave = records.where((r) => r.status == AttendanceStatus.leave).length;
        final other = records.where((r) => r.status == AttendanceStatus.other).length;

        tasksConfirmData.add({
          'task_id': taskId,
          'class_names': classNames,
          'total': total,
          'present': present,
          'absent': absent,
          'late': late,
          'leave': leave,
          'other': other,
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      LoggerService.sync('获取确认数据失败: $e', isError: true);
      Toast.show(context, '获取任务数据失败，请重试');
      return;
    }

    setState(() => _loading = false);

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SubmissionConfirmDialog(
        tasksData: tasksConfirmData,
      ),
    );

    if (confirmed != true) {
      return;
    }

    // 用户确认后再做一次轻量校验：避免在确认对话框停留期间，
    // 后台同步又失败、或被其他设备改坏数据导致绕过前面的校验。
    {
      final localDS = ref.read(attendanceLocalDSProvider);
      final issueCount = await localDS.getSyncIssueCount();
      if (issueCount > 0) {
        if (mounted) {
          Toast.show(context, '检测到 $issueCount 条同步问题，请处理后再提交');
        }
        return;
      }
      final repo = ref.read(attendanceRepositoryProvider);
      final invalid = <String>[];
      for (final taskId in _selectedTaskIds) {
        final task = await repo.getTask(taskId);
        if (task == null || task.status != TaskStatus.completed) {
          invalid.add(taskId);
        }
      }
      if (invalid.isNotEmpty) {
        if (mounted) {
          Toast.show(
            context,
            '${invalid.length} 个任务状态已变化，请重新选择后提交',
          );
          setState(() {
            _selectedTaskIds.removeWhere((id) => invalid.contains(id));
          });
          ref.invalidate(weekNameCheckTasksProvider(weekNumber));
        }
        return;
      }
    }

    // 用户确认后执行提交
    setState(() => _loading = true);

    int successCount = 0;
    int failCount = 0;
    // 用任务 id → 错误详情映射，便于后续聚合展示
    final errors = <String, String>{};
    // 任务 id → 班级名（用于在错误详情中显示更友好的标识）
    final taskLabels = <String, String>{
      for (final t in tasksConfirmData)
        t['task_id'] as String:
            (t['class_names'] as List?)?.join('、') ?? (t['task_id'] as String),
    };

    for (final taskId in _selectedTaskIds) {
      try {
        final service = ref.read(submissionServiceProvider);
        await service.createSubmission(
          weekNumber: weekNumber,
          taskIds: [taskId],
        );
        successCount++;
      } catch (e) {
        failCount++;
        // 优先取 Exception("提交失败: detail") 的 detail 部分
        final raw = e.toString();
        final detail = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
        errors[taskId] = detail;
        LoggerService.error('提交失败 [$taskId]: $detail');
      }
    }

    if (mounted) {
      if (failCount == 0) {
        Toast.show(context, '成功提交 $successCount 个任务');
      } else if (successCount == 0 && errors.length == 1) {
        // 只有一个失败：直接 toast，避免无谓弹窗
        Toast.show(context, '提交失败: ${errors.values.first}');
      } else {
        // 多项混合结果：展示聚合详情，避免吞掉除第一条以外的错误
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              failCount > 0 ? Icons.error_outline : Icons.check_circle_outline,
              color: failCount > 0 ? Colors.red : Colors.green,
              size: 40,
            ),
            title: Text('提交完成: $successCount 成功 / $failCount 失败'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: errors.entries.map((entry) {
                    final label = taskLabels[entry.key] ?? entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(entry.value),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
      _selectedTaskIds = [];
      ref.invalidate(submittedTaskIdsProvider);
      ref.invalidate(weekNameCheckTasksProvider);
      ref.invalidate(mySubmissionsProvider);
      _tabController.animateTo(1);
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentWeekAsync = ref.watch(currentWeekProvider);
    final myDutyAsync = ref.watch(myDutyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('名单提交'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '提交任务'),
            Tab(text: '我的提交'),
          ],
        ),
      ),
      body: currentWeekAsync.when(
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text('加载失败: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(currentWeekProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (weekData) {
          final weekNumber = weekData['week_number'] as int;

          return myDutyAsync.when(
            loading: () => const LoadingOverlay(
              isLoading: true,
              child: SizedBox.expand(),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('加载职务状态失败: $e'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(myDutyProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
            data: (duty) {
              final hasDuty = duty['has_duty'] as bool? ?? false;

              if (!hasDuty) {
                return _buildNoDutyView(context);
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _SubmitTaskTab(
                    weekNumber: weekNumber,
                    selectedTaskIds: _selectedTaskIds,
                    loading: _loading,
                    onSelectionChanged: (ids) =>
                        setState(() => _selectedTaskIds = ids),
                    onSubmit: () => _submit(weekNumber),
                  ),
                  _MySubmissionsTab(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNoDutyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('您没有被分配查课职务', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('无需提交考勤记录', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.push('/extension/weekly-summary'),
              child: const Text('查看周名单汇总'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitTaskTab extends ConsumerWidget {
  final int weekNumber;
  final List<String> selectedTaskIds;
  final bool loading;
  final void Function(List<String>) onSelectionChanged;
  final VoidCallback onSubmit;

  const _SubmitTaskTab({
    required this.weekNumber,
    required this.selectedTaskIds,
    required this.loading,
    required this.onSelectionChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(adminsProvider);
    final tasksAsync = ref.watch(weekNameCheckTasksProvider(weekNumber));
    final issueCount = ref.watch(syncIssueCountProvider);
    final syncState = ref.watch(syncStateProvider);
    final hasSyncFailed = ref.watch(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.when(
      data: (failed) => failed,
      loading: () => false,
      error: (_, __) => false,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未同步记录提示
          issueCount.when(
            data: (count) {
              if (count == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: isSyncFailed
                      ? Colors.red.withValues(alpha: 0.1)
                      : syncState == SyncState.syncing
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSyncFailed
                          ? Colors.red.withValues(alpha: 0.3)
                          : syncState == SyncState.syncing
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          isSyncFailed
                              ? Icons.error_outline
                              : syncState == SyncState.syncing
                                  ? Icons.sync
                                  : Icons.warning_amber,
                          color: isSyncFailed
                              ? Colors.red
                              : syncState == SyncState.syncing
                                  ? Colors.blue
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSyncFailed
                                ? '有 $count 条同步失败，请先处理后再提交'
                                : syncState == SyncState.syncing
                                    ? '正在自动同步 $count 条记录，请稍候再提交'
                                    : '有 $count 条记录待同步，系统将在后台自动处理',
                            style: TextStyle(
                              color: isSyncFailed
                                  ? Colors.red.shade800
                                  : syncState == SyncState.syncing
                                      ? Colors.blue.shade800
                                      : Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '第 $weekNumber 周',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  adminsAsync.when(
                    loading: () => const Text('加载管理员列表...'),
                    error: (e, _) => const Text('待审核管理员'),
                    data: (admins) {
                      if (admins.isEmpty) return const Text('待审核管理员');
                      final names = admins
                          .map((a) => a['real_name'] ?? a['email'])
                          .join('、');
                      return Text(
                        '待审核管理员: $names',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('本周记名任务', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('加载失败: $e'),
                ],
              ),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return EmptyStateCard.noTask();
              }

              return Card(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index] as Map<String, dynamic>;
                    final taskId = task['id'] as String;
                    final isSelected = selectedTaskIds.contains(taskId);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        if (checked == true) {
                          onSelectionChanged([...selectedTaskIds, taskId]);
                        } else {
                          onSelectionChanged(
                            selectedTaskIds
                                .where((id) => id != taskId)
                                .toList(),
                          );
                        }
                      },
                      title: Text(
                        (task['class_names'] as List?)?.join(', ') ?? '未知班级',
                      ),
                      subtitle: Text(
                        '${task['record_count']} 条记录 · ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(task['created_at'] as String))}',
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (selectedTaskIds.isNotEmpty)
            Text(
              '已选择 ${selectedTaskIds.length} 个任务',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          const SizedBox(height: 16),
          _SubmitButton(
            loading: loading,
            issueCount: issueCount,
            syncState: syncState,
            onSubmit: onSubmit,
          ),
          const SizedBox(height: 24),
          Text('说明', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '• 只有记名任务需要提交\n'
            '• 只能提交本周任务\n'
            '• 已提交的任务不可重复提交',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends ConsumerWidget {
  final bool loading;
  final AsyncValue<int> issueCount;
  final SyncState syncState;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.loading,
    required this.issueCount,
    required this.syncState,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 如果正在提交中（弹出确认对话框后），显示 loading
    if (loading) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // 监听同步状态和同步问题数量
    final isSyncing = syncState == SyncState.syncing;
    final count = issueCount.valueOrNull ?? 0;
    final hasIssues = count > 0;

    // 检查是否有同步失败数据
    final hasSyncFailed = ref.watch(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.when(
      data: (failed) => failed,
      loading: () => false,
      error: (_, __) => false,
    );

    // 如果有同步失败数据，禁用按钮并显示红色提示
    if (isSyncFailed) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 18),
            const SizedBox(width: 8),
            Text('有 $count 条同步失败，请先处理'),
          ],
        ),
      );
    }

    // 如果正在同步或有同步问题，禁用按钮并显示提示
    if (isSyncing || hasIssues) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              isSyncing
                  ? '正在同步 $count 条记录...'
                  : '有 $count 条记录待同步，请等待',
            ),
          ],
        ),
      );
    }

    // 正常状态：可以提交
    return FilledButton(
      onPressed: onSubmit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      child: const Text('提交审核'),
    );
  }
}

class _MySubmissionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(mySubmissionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mySubmissionsProvider);
      },
      child: submissionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('加载失败: $e'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(mySubmissionsProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (submissions) {
          if (submissions.isEmpty) {
            return EmptyState.noSubmission();
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final submission = submissions[index] as Map<String, dynamic>;
              return _SubmissionCard(submission: submission);
            },
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends ConsumerWidget {
  final Map<String, dynamic> submission;

  const _SubmissionCard({required this.submission});

  Color _getStatusColor() {
    final status = submission['status'] as String;
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    final status = submission['status'] as String;
    switch (status) {
      case 'pending':
        return '待审核';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'cancelled':
        return '已撤销';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submittedAt = DateTime.parse(submission['submitted_at'] as String);
    final reviewerName = submission['reviewer_name'] as String?;
    final status = submission['status'] as String;
    final canCancel = status == 'pending';
    final classNames = submission['class_names'] as String?;
    final recordCount = submission['record_count'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classNames ?? '未知班级',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  StatusBadge(
                    label: _getStatusText(),
                    color: _getStatusColor(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '第 ${submission['week_number']} 周',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· $recordCount 条记录',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(submittedAt),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (reviewerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '审核人: $reviewerName',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (submission['review_note'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '备注: ${submission['review_note']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.visibility, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '点击查看详情',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                  const Spacer(),
                  if (canCancel)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('撤回'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showCancelDialog(context, ref),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailDialog(BuildContext context, WidgetRef ref) async {
    final submissionId = submission['id'] as int;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('加载详情...'),
          ],
        ),
      ),
    );

    try {
      final service = ref.read(submissionServiceProvider);
      final data = await service.getSubmissionRecords(submissionId);

      Navigator.of(context, rootNavigator: true).pop();

      final status = data['status'] as String?;
      if (status == 'cancelled') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提交详情'),
            content: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('该提交已被撤销'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
        return;
      }

      final records = data['records'] as List? ?? [];
      final lateCount = data['late_count'] as int? ?? 0;
      final absentCount = data['absent_count'] as int? ?? 0;
      final leaveCount = data['leave_count'] as int? ?? 0;
      final otherCount = data['other_count'] as int? ?? 0;
      final recordCount = records.length;
      final submissionStatus = data['status'] as String?;
      final isRejected = submissionStatus == 'rejected';

      final lateRecords = records.where((r) => r['status'] == 'late').toList();
      final absentRecords = records
          .where((r) => r['status'] == 'absent')
          .toList();
      final leaveRecords = records
          .where((r) => r['status'] == 'leave')
          .toList();
      final otherRecords = records
          .where((r) => r['status'] == 'other')
          .toList();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('提交详情 - 第 ${submission['week_number']} 周'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // rejected 状态提示
                if (isRejected) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cancel, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              '已拒绝',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (submission['reviewer_name'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '审核人: ${submission['reviewer_name']}',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                        if (submission['review_note'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '拒绝原因: ${submission['review_note']}',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMiniStat('迟到', lateCount, Colors.orange),
                    _buildMiniStat('缺勤', absentCount, Colors.red),
                    _buildMiniStat('请假', leaveCount, Colors.blue),
                    _buildMiniStat('其他', otherCount, Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                if (recordCount == 0)
                  EmptyState.noLinkedRecords()
                else if (lateCount + absentCount + leaveCount + otherCount == 0)
                  EmptyState.noAbnormalRecords(),
                if (absentRecords.isNotEmpty) ...[
                  const Text(
                    '缺勤名单:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...absentRecords.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '- ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (lateRecords.isNotEmpty) ...[
                  const Text(
                    '迟到名单:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...lateRecords.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '- ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (leaveRecords.isNotEmpty) ...[
                  const Text(
                    '请假名单:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...leaveRecords.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '- ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (otherRecords.isNotEmpty) ...[
                  const Text(
                    '其他名单:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...otherRecords.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '- ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      Toast.show(context, '加载详情失败: $e');
    }
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $count', style: TextStyle(color: color)),
    );
  }

  Future<void> _showCancelDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回提交'),
        content: const Text('确定要撤回此提交吗？撤回后可以重新提交。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认撤回'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(submissionServiceProvider);
        await service.cancelSubmission(submission['id'] as int);
        ref.invalidate(mySubmissionsProvider);
        ref.invalidate(submittedTaskIdsProvider);
        Toast.show(context, '已撤回');
      } on DioException catch (e) {
        final message = e.response?.data['detail'] ?? '撤回失败';
        Toast.show(context, message);
      } catch (e) {
        Toast.show(context, '撤回失败: $e');
      }
    }
  }
}

/// 提交确认对话框：显示每个任务的统计信息，让用户确认后再提交
class _SubmissionConfirmDialog extends StatelessWidget {
  final List<Map<String, dynamic>> tasksData;

  const _SubmissionConfirmDialog({required this.tasksData});

  @override
  Widget build(BuildContext context) {
    final hasAbnormal = tasksData.any((t) {
      final absent = t['absent'] as int? ?? 0;
      final late = t['late'] as int? ?? 0;
      final leave = t['leave'] as int? ?? 0;
      final other = t['other'] as int? ?? 0;
      return absent + late + leave + other > 0;
    });

    return AlertDialog(
      icon: const Icon(Icons.fact_check, size: 48, color: Colors.orange),
      title: const Text('确认提交名单'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '请仔细检查以下名单，确认无误后再提交：',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...tasksData.map((task) => _buildTaskCard(context, task)),
              if (hasAbnormal) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '注意：部分任务存在异常记录，请确认状态是否正确',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('确认提交'),
        ),
      ],
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final classNames = (task['class_names'] as List?)?.join('、') ?? '未知班级';
    final total = task['total'] as int? ?? 0;
    final present = task['present'] as int? ?? 0;
    final absent = task['absent'] as int? ?? 0;
    final late = task['late'] as int? ?? 0;
    final leave = task['leave'] as int? ?? 0;
    final other = task['other'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classNames,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatChip('共$total人', Colors.grey),
                _buildStatChip('到$present', Colors.green),
                if (absent > 0) _buildStatChip('缺$absent', Colors.red),
                if (late > 0) _buildStatChip('迟$late', Colors.amber.shade700),
                if (leave > 0) _buildStatChip('假$leave', Colors.blue),
                if (other > 0) _buildStatChip('他$other', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
