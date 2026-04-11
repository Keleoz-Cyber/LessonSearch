import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../../../core/network/api_client.dart';
import '../../../features/attendance/domain/models.dart';
import '../data/submission_service.dart';
import '../presentation/weekly_summary_page.dart';

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
  } catch (e) {
    return {'has_duty': false};
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

final localNameCheckTasksProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  final studentRepo = ref.watch(studentRepositoryProvider);
  final submittedIds = await ref.watch(submittedTaskIdsProvider.future);

  final tasks = await repo.getCompletedNameCheckTasks();

  final startOfWeek = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );
  final weekStart = DateTime(
    startOfWeek.year,
    startOfWeek.month,
    startOfWeek.day,
  );

  final weekTasks = tasks
      .where(
        (t) => t.createdAt.isAfter(weekStart) && !submittedIds.contains(t.id),
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

class _SubmissionPageState extends ConsumerState<SubmissionPage> {
  List<String> _selectedTaskIds = [];
  bool _loading = false;

  Future<void> _submit(int weekNumber) async {
    if (_selectedTaskIds.isEmpty) {
      Toast.show(context, '请选择要提交的任务');
      return;
    }

    setState(() => _loading = true);

    try {
      final service = ref.read(submissionServiceProvider);
      await service.createSubmission(
        weekNumber: weekNumber,
        taskIds: _selectedTaskIds,
      );

      if (mounted) {
        Toast.show(context, '提交成功，等待审核');
        ref.invalidate(mySubmissionsProvider);
        ref.invalidate(pendingSubmissionsProvider);
        context.push('/extension/weekly-summary');
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, '提交失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeekAsync = ref.watch(currentWeekProvider);
    final myDutyAsync = ref.watch(myDutyProvider);
    final adminsAsync = ref.watch(adminsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('名单提交')),
      body: currentWeekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('加载职务状态失败: $e'),
                ],
              ),
            ),
            data: (duty) {
              final hasDuty = duty['has_duty'] as bool? ?? false;

              if (!hasDuty) {
                return _buildNoDutyView(context);
              }

              final tasksAsync = ref.watch(localNameCheckTasksProvider);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '本周记名任务（本地）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    tasksAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text('加载失败: $e'),
                          ],
                        ),
                      ),
                      data: (tasks) {
                        if (tasks.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.inbox_outlined,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('暂无本周记名任务'),
                                    const SizedBox(height: 8),
                                    Text(
                                      '请先创建记名任务后再提交',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: () =>
                                          context.go('/name-check/select'),
                                      child: const Text('创建记名任务'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Card(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index] as Map<String, dynamic>;
                              final taskId = task['id'] as String;
                              final isSelected = _selectedTaskIds.contains(
                                taskId,
                              );

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (checked) {
                                  if (checked == true) {
                                    setState(() {
                                      _selectedTaskIds = [
                                        ..._selectedTaskIds,
                                        taskId,
                                      ];
                                    });
                                  } else {
                                    setState(() {
                                      _selectedTaskIds = _selectedTaskIds
                                          .where((id) => id != taskId)
                                          .toList();
                                    });
                                  }
                                },
                                title: Text(
                                  (task['class_names'] as List?)?.join(', ') ??
                                      '未知班级',
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
                    if (_selectedTaskIds.isNotEmpty)
                      Text(
                        '已选择 ${_selectedTaskIds.length} 个任务',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : () => _submit(weekNumber),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('提交审核'),
                    ),
                    const SizedBox(height: 24),
                    Text('说明', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      '• 只有记名任务需要提交，点名任务不参与提交\n'
                      '• 只能提交本周任务，不支持跨周提交\n'
                      '• 提交后等待管理员审核\n'
                      '• 已提交的记录将被锁定，不可修改',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
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
