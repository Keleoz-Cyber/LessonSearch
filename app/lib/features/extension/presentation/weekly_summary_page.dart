import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../../../core/network/api_client.dart';
import '../data/submission_service.dart';

final currentWeekProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/week/current');
  return res.data as Map<String, dynamic>;
});

final mySubmissionsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(submissionServiceProvider).getMySubmissions();
});

final pendingSubmissionsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(submissionServiceProvider).getPendingSubmissions();
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

final submissionServiceProvider = Provider<SubmissionService>((ref) {
  return SubmissionService(ref.watch(apiClientProvider));
});

class WeeklySummaryPage extends ConsumerStatefulWidget {
  const WeeklySummaryPage({super.key});

  @override
  ConsumerState<WeeklySummaryPage> createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends ConsumerState<WeeklySummaryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedWeek = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final currentWeekAsync = ref.watch(currentWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('周名单汇总'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(currentWeekProvider);
              ref.invalidate(mySubmissionsProvider);
              ref.invalidate(pendingSubmissionsProvider);
              ref.invalidate(myDutyProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本周汇总'),
            Tab(text: '历史周次'),
            Tab(text: '我的提交'),
          ],
        ),
      ),
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
          if (_selectedWeek == 0) {
            _selectedWeek = weekNumber;
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _CurrentWeekTab(
                weekNumber: weekNumber,
                weekData: weekData,
                isAdmin: auth.isAdmin,
              ),
              _HistoryWeekTab(
                currentWeek: weekNumber,
                isAdmin: auth.isAdmin,
                onWeekSelected: (w) => setState(() => _selectedWeek = w),
              ),
              _MySubmissionsTab(),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentWeekTab extends ConsumerWidget {
  final int weekNumber;
  final Map<String, dynamic> weekData;
  final bool isAdmin;

  const _CurrentWeekTab({
    required this.weekNumber,
    required this.weekData,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSubmissionsProvider);
    final myDutyAsync = ref.watch(myDutyProvider);
    final startDate = DateTime.parse(weekData['start_date'] as String);
    final endDate = DateTime.parse(weekData['end_date'] as String);
    final semesterName = weekData['semester_name'] as String?;

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '第 $weekNumber 周',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          '进行中',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (semesterName != null)
                    Text(
                      semesterName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    '${DateFormat('MM月dd日').format(startDate)} - ${DateFormat('MM月dd日').format(endDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (isAdmin) ...[
            Text('待审核提交', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载失败: $e'),
              data: (pending) {
                if (pending.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Colors.green,
                            ),
                            SizedBox(height: 8),
                            Text('暂无待审核提交'),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: pending
                      .map((s) => _PendingSubmissionCard(submission: s))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('导出并发布本周汇总'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _showExportDialog(context, ref, weekNumber),
            ),
          ] else ...[
            myDutyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载职务状态失败'),
              data: (duty) {
                final hasDuty = duty['has_duty'] as bool? ?? false;
                if (!hasDuty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('您没有被分配查课职务'),
                            SizedBox(height: 8),
                            Text(
                              '无需提交考勤记录',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          const Text('您已被分配查课职务'),
                          const SizedBox(height: 8),
                          Text(
                            '分配时间: ${duty['assigned_at'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(duty['assigned_at'])) : '未知'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExportDialog(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出确认'),
        content: const Text(
          '导出后，本周汇总名单将对所有成员可见。\n\n'
          '确定要导出并发布吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认导出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _doExport(context, ref, weekNumber);
    }
  }

  Future<void> _doExport(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
  ) async {
    try {
      final api = ref.read(apiClientProvider);

      final response = await api.dio.get(
        '/submissions/export/$weekNumber',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data as List<int>);
      final filename = '第${weekNumber}周周考勤表.xlsx';

      if (Platform.isAndroid) {
        final dir = Directory('/storage/emulated/0/Download');
        if (await dir.exists()) {
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          Toast.show(context, '已保存到: ${dir.path}/$filename');
        } else {
          Toast.show(context, '导出成功，请检查浏览器下载');
        }
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        Toast.show(context, '已保存: ${file.path}');
      } else {
        Toast.show(context, '导出成功');
      }

      ref.invalidate(pendingSubmissionsProvider);
    } catch (e) {
      Toast.show(context, '导出失败: $e');
    }
  }
}

class _PendingSubmissionCard extends ConsumerWidget {
  final Map<String, dynamic> submission;

  const _PendingSubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName =
        submission['user_name'] ?? submission['user_email'] ?? '未知';
    final submittedAt = DateTime.parse(submission['submitted_at'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(submittedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '待审核',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${submission['task_count']} 个任务，${submission['record_count']} 条记录',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('拒绝'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => _showRejectDialog(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('通过'),
                    onPressed: () => _approve(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(submissionServiceProvider);
      await service.approveSubmission(submission['id']);

      ref.invalidate(pendingSubmissionsProvider);
      Toast.show(context, '审核通过');
    } catch (e) {
      Toast.show(context, '操作失败: $e');
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拒绝理由'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入拒绝理由',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认拒绝'),
          ),
        ],
      ),
    );

    if (result == true) {
      final note = controller.text.trim();
      if (note.isEmpty) {
        Toast.show(context, '请输入拒绝理由');
        return;
      }

      try {
        final service = ref.read(submissionServiceProvider);
        await service.rejectSubmission(submission['id'], note);

        ref.invalidate(pendingSubmissionsProvider);
        Toast.show(context, '已拒绝');
      } catch (e) {
        Toast.show(context, '操作失败: $e');
      }
    }
  }
}

class _HistoryWeekTab extends StatelessWidget {
  final int currentWeek;
  final bool isAdmin;
  final void Function(int) onWeekSelected;

  const _HistoryWeekTab({
    required this.currentWeek,
    required this.isAdmin,
    required this.onWeekSelected,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = List.generate(currentWeek, (i) => currentWeek - i);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final week = weeks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text('第 $week 周'),
            subtitle: week == currentWeek ? const Text('当前周') : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              onWeekSelected(week);
              Toast.show(context, '周次详情功能暂未开发');
            },
          ),
        );
      },
