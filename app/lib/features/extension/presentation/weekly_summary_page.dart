import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../data/submission_service.dart';

final currentWeekProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/week/current');
  return res.data as Map<String, dynamic>;
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

final exportStatusProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  weekNumber,
) {
  return ref.watch(submissionServiceProvider).getExportStatus(weekNumber);
});

final weekSummaryProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  weekNumber,
) {
  return ref.watch(submissionServiceProvider).getWeekSummary(weekNumber);
});

final weekSubmissionStatusProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, weekNumber) {
      return ref
          .watch(submissionServiceProvider)
          .getWeekSubmissionStatus(weekNumber);
    });

final submissionRecordsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, submissionId) {
      return ref
          .watch(submissionServiceProvider)
          .getSubmissionRecords(submissionId);
    });

final weekSummaryDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, weekNumber) {
      return ref
          .watch(submissionServiceProvider)
          .getWeekSummaryDetail(weekNumber);
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && mounted) {
      final weekData = ref.read(currentWeekProvider).valueOrNull;
      if (weekData != null) {
        final weekNumber = weekData['week_number'] as int;
        ref.invalidate(pendingSubmissionsProvider);
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        ref.invalidate(weekSummaryProvider(weekNumber));
        ref.invalidate(myDutyProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final currentWeekAsync = ref.watch(currentWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('周名单汇总'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本周汇总'),
            Tab(text: '历史周次'),
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

          return TabBarView(
            controller: _tabController,
            children: [
              _CurrentWeekTab(
                weekNumber: weekNumber,
                weekData: weekData,
                isAdmin: auth.isAdmin,
              ),
              _HistoryWeekTab(currentWeek: weekNumber, isAdmin: auth.isAdmin),
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
    final submissionStatusAsync = ref.watch(
      weekSubmissionStatusProvider(weekNumber),
    );
    final weekSummaryAsync = ref.watch(weekSummaryProvider(weekNumber));
    final exportStatusAsync = ref.watch(exportStatusProvider(weekNumber));
    final startDate = DateTime.parse(weekData['start_date'] as String);
    final endDate = DateTime.parse(weekData['end_date'] as String);
    final semesterName = weekData['semester_name'] as String?;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingSubmissionsProvider);
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        ref.invalidate(weekSummaryProvider(weekNumber));
        ref.invalidate(exportStatusProvider(weekNumber));
        ref.invalidate(myDutyProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekHeader(
              context,
              weekNumber,
              semesterName,
              startDate,
              endDate,
              exportStatusAsync,
            ),
            const SizedBox(height: 16),

            if (isAdmin) ...[
              _buildAdminSection(
                context,
                ref,
                pendingAsync,
                submissionStatusAsync,
                weekSummaryAsync,
                weekNumber,
              ),
            ] else ...[
              _buildMemberSection(
                context,
                ref,
                exportStatusAsync,
                weekSummaryAsync,
                weekNumber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekHeader(
    BuildContext context,
    int weekNumber,
    String? semesterName,
    DateTime startDate,
    DateTime endDate,
    AsyncValue<Map<String, dynamic>> exportStatusAsync,
  ) {
    return Card(
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
                exportStatusAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (status) {
                    final isPublished =
                        status['is_published'] as bool? ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPublished
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isPublished ? '已发布' : '未发布',
                        style: TextStyle(
                          color: isPublished ? Colors.green : Colors.orange,
                        ),
                      ),
                    );
                  },
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
    );
  }

  Widget _buildAdminSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> pendingAsync,
    AsyncValue<Map<String, dynamic>> submissionStatusAsync,
    AsyncValue<Map<String, dynamic>> weekSummaryAsync,
    int weekNumber,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        submissionStatusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载提交状态失败: $e'),
          data: (status) => _buildSubmissionStatusCard(context, status),
        ),
        const SizedBox(height: 16),

        weekSummaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载汇总统计失败: $e'),
          data: (summary) =>
              _buildSummaryPreviewCard(context, ref, summary, weekNumber),
        ),
        const SizedBox(height: 16),

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
                  .map(
                    (s) => _PendingSubmissionCard(
                      submission: s,
                      weekNumber: weekNumber,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('导出并发布本周汇总'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => _showExportDialog(context, ref, weekNumber),
        ),
      ],
    );
  }

  Widget _buildSubmissionStatusCard(
    BuildContext context,
    Map<String, dynamic> status,
  ) {
    final totalDuty = status['total_duty'] as int? ?? 0;
    final submittedCount = status['submitted_count'] as int? ?? 0;
    final notSubmittedCount = status['not_submitted_count'] as int? ?? 0;
    final submittedMembers = status['submitted_members'] as List? ?? [];
    final notSubmittedMembers = status['not_submitted_members'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('提交状态', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  '有职务: $totalDuty人  已提交: $submittedCount人  未提交: $notSubmittedCount人',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (submittedMembers.isNotEmpty) ...[
              Text(
                '已提交',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              ...submittedMembers.map(
                (m) => _buildMemberStatusItem(context, m, true),
              ),
              const SizedBox(height: 12),
            ],

            if (notSubmittedMembers.isNotEmpty) ...[
              Text(
                '未提交',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              ...notSubmittedMembers.map(
                (m) => _buildMemberStatusItem(context, m, false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberStatusItem(
    BuildContext context,
    Map<String, dynamic> member,
    bool submitted,
  ) {
    final userName = member['user_name'] as String? ?? '未知';
    final pendingCount = member['pending_count'] as int? ?? 0;
    final approvedCount = member['approved_count'] as int? ?? 0;
    final rejectedCount = member['rejected_count'] as int? ?? 0;
    final submissionCount = member['submission_count'] as int? ?? 0;

    String statusText;
    Color statusColor;
    if (submitted) {
      if (pendingCount > 0) {
        statusText = '$submissionCount个提交 ($pendingCount待审核)';
        statusColor = Colors.orange;
      } else if (rejectedCount > 0) {
        statusText = '$submissionCount个提交 ($rejectedCount已拒绝)';
        statusColor = Colors.red;
      } else {
        statusText = '$approvedCount个提交已通过';
        statusColor = Colors.green;
      }
    } else {
      statusText = '未提交';
      statusColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            submitted ? Icons.check_circle : Icons.hourglass_top,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(userName)),
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummaryPreviewCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> summary,
    int weekNumber,
  ) {
    final lateCount = summary['late_count'] as int? ?? 0;
    final absentCount = summary['absent_count'] as int? ?? 0;
    final approvedCount = summary['approved_count'] as int? ?? 0;
    final pendingCount = summary['pending_count'] as int? ?? 0;
    final total = (lateCount / 2).floor() + absentCount;

    return Card(
      child: InkWell(
        onTap: () => _showSummaryDetailDialog(context, ref, weekNumber),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('汇总预览', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '迟到/早退',
                      lateCount,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '旷课',
                      absentCount,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(context, '累计', total, Colors.purple),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '待审核',
                      pendingCount,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '已通过',
                      approvedCount,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '点击查看详细名单',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSummaryDetailDialog(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在加载...'),
          ],
        ),
      ),
    );

    try {
      final detail = await ref
          .read(submissionServiceProvider)
          .getWeekSummaryDetail(weekNumber);

      Navigator.of(context, rootNavigator: true).pop();

      final tableData = (detail['table_data'] as List? ?? [])
          .map((r) => r as Map<String, dynamic>)
          .toList();

      showDialog(
        context: context,
        builder: (ctx) =>
            _SummaryDetailDialog(weekNumber: weekNumber, tableData: tableData),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      Toast.show(context, '加载详情失败: $e');
    }
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> exportStatusAsync,
    AsyncValue<Map<String, dynamic>> weekSummaryAsync,
    int weekNumber,
  ) {
    final myDutyAsync = ref.watch(myDutyProvider);

    return exportStatusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('加载发布状态失败: $e'),
      data: (exportStatus) {
        final isPublished = exportStatus['is_published'] as bool? ?? false;

        if (!isPublished) {
          return Column(
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_top,
                          size: 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text('本周汇总名单尚未发布'),
                        SizedBox(height: 8),
                        Text(
                          '请等待管理员导出后查看',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              myDutyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载职务状态失败'),
                data: (duty) => _buildDutyStatusCard(context, duty),
              ),
            ],
          );
        }

        return weekSummaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载汇总数据失败: $e'),
          data: (summary) => _buildPublishedSection(
            context,
            ref,
            summary,
            exportStatus,
            weekNumber,
          ),
        );
      },
    );
  }

  Widget _buildDutyStatusCard(BuildContext context, Map<String, dynamic> duty) {
    final hasDuty = duty['has_duty'] as bool? ?? false;
    if (!hasDuty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('您没有被分配查课职务'),
                SizedBox(height: 8),
                Text('无需提交考勤记录', style: TextStyle(color: Colors.grey)),
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
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
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
  }

  Widget _buildPublishedSection(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> summary,
    Map<String, dynamic> exportStatus,
    int weekNumber,
  ) {
    final lateCount = summary['late_count'] as int? ?? 0;
    final absentCount = summary['absent_count'] as int? ?? 0;
    final approvedCount = summary['approved_count'] as int? ?? 0;
    final exportedAt = exportStatus['exported_at'] as String?;
    final exportedByName = exportStatus['exported_by_name'] as String?;
    final total = (lateCount / 2).floor() + absentCount;

    return Card(
      child: InkWell(
        onTap: () => _showSummaryDetailDialog(context, ref, weekNumber),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('本周汇总已发布')),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              if (exportedByName != null)
                Text(
                  '导出人: $exportedByName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (exportedAt != null)
                Text(
                  '导出时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(exportedAt))}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const Divider(height: 24),
              Text('本周统计', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '迟到/早退',
                      lateCount,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '旷课',
                      absentCount,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context,
                      '已审核提交',
                      approvedCount,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '累计: $total 次',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击查看详细名单',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
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
        content: const Text('导出后，本周汇总名单将对所有成员可见。\n\n确定要导出并发布吗？'),
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
          Toast.show(context, '导出成功');
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
      ref.invalidate(exportStatusProvider(weekNumber));
      ref.invalidate(weekSummaryProvider(weekNumber));
    } catch (e) {
      Toast.show(context, '导出失败: $e');
    }
  }
}

class _PendingSubmissionCard extends ConsumerWidget {
  final Map<String, dynamic> submission;
  final int weekNumber;

  const _PendingSubmissionCard({
    required this.submission,
    required this.weekNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName =
        submission['user_name'] ?? submission['user_email'] ?? '未知';
    final submittedAt = DateTime.parse(submission['submitted_at'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetailDialog(context, ref),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  Future<void> _showDetailDialog(BuildContext context, WidgetRef ref) async {
    final submissionId = submission['id'] as int;
    final submissionStatus = submission['status'] as String;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('审核详情 - ${submission['user_name'] ?? '未知'}'),
        content: SizedBox(
          width: 400,
          child: submissionStatus == 'cancelled'
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('该提交已被撤销'),
                      SizedBox(height: 8),
                      Text(
                        '成员已撤销此提交，无法审核',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<Map<String, dynamic>>(
                  future: ref
                      .read(submissionServiceProvider)
                      .getSubmissionRecords(submissionId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('加载失败: ${snapshot.error}');
                    }

                    final data = snapshot.data!;
                    final status = data['status'] as String?;
                    if (status == 'cancelled') {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('该提交已被撤销'),
                            SizedBox(height: 8),
                            Text(
                              '成员已撤销此提交，无法审核',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    final records = data['records'] as List? ?? [];
                    final lateCount = data['late_count'] as int? ?? 0;
                    final absentCount = data['absent_count'] as int? ?? 0;
                    final leaveCount = data['leave_count'] as int? ?? 0;

                    final lateRecords = records
                        .where((r) => r['status'] == 'late')
                        .toList();
                    final absentRecords = records
                        .where((r) => r['status'] == 'absent')
                        .toList();

                    if (records.isEmpty) {
                      return const Center(child: Text('暂无异常记录'));
                    }

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _buildMiniStat('迟到', lateCount, Colors.orange),
                              const SizedBox(width: 12),
                              _buildMiniStat('缺勤', absentCount, Colors.red),
                              const SizedBox(width: 12),
                              _buildMiniStat('请假', leaveCount, Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (absentRecords.isNotEmpty) ...[
                            const Text(
                              '缺勤名单:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...absentRecords.map(
                              (r) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  '- ${r['student_name']} (${r['student_no']}) ${r['class_name']}',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          if (submissionStatus != 'cancelled') ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(context, ref);
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('拒绝'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _approve(context, ref);
              },
              child: const Text('通过'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(submissionServiceProvider);
      await service.approveSubmission(submission['id']);
      ref.invalidate(pendingSubmissionsProvider);
      ref.invalidate(weekSummaryProvider(weekNumber));
      ref.invalidate(weekSubmissionStatusProvider(weekNumber));
      Toast.show(context, '审核通过');
    } on DioException catch (e) {
      final message = e.response?.data['detail'] ?? '操作失败';
      Toast.show(context, message);
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
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        Toast.show(context, '已拒绝');
      } on DioException catch (e) {
        final message = e.response?.data['detail'] ?? '操作失败';
        Toast.show(context, message);
      } catch (e) {
        Toast.show(context, '操作失败: $e');
      }
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
}

class _HistoryWeekTab extends ConsumerWidget {
  final int currentWeek;
  final bool isAdmin;

  const _HistoryWeekTab({required this.currentWeek, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = List.generate(currentWeek, (i) => currentWeek - i);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final week = weeks[index];
        return _HistoryWeekCard(
          weekNumber: week,
          currentWeek: currentWeek,
          isAdmin: isAdmin,
        );
      },
    );
  }
}

class _HistoryWeekCard extends ConsumerWidget {
  final int weekNumber;
  final int currentWeek;
  final bool isAdmin;

  const _HistoryWeekCard({
    required this.weekNumber,
    required this.currentWeek,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportStatusAsync = ref.watch(exportStatusProvider(weekNumber));
    final weekSummaryAsync = ref.watch(weekSummaryProvider(weekNumber));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showWeekDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '第 $weekNumber 周',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (weekNumber == currentWeek)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    exportStatusAsync.when(
                      loading: () => const Text('加载状态...'),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (status) {
                        final isPublished =
                            status['is_published'] as bool? ?? false;
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPublished
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPublished ? '已发布' : '未发布',
                                style: TextStyle(
                                  color: isPublished
                                      ? Colors.green
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (isPublished)
                              weekSummaryAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (summary) {
                                  final lateCount =
                                      summary['late_count'] as int? ?? 0;
                                  final absentCount =
                                      summary['absent_count'] as int? ?? 0;
                                  final total =
                                      (lateCount / 2).floor() + absentCount;
                                  if (total > 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '异常: $total人',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWeekDetail(BuildContext context, WidgetRef ref) async {
    final exportStatus = await ref
        .read(submissionServiceProvider)
        .getExportStatus(weekNumber);
    final isPublished = exportStatus['is_published'] as bool? ?? false;

    if (!isPublished && !isAdmin) {
      Toast.show(context, '该周汇总尚未发布');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在加载...'),
          ],
        ),
      ),
    );

    try {
      final detail = await ref
          .read(submissionServiceProvider)
          .getWeekSummaryDetail(weekNumber);

      Navigator.of(context, rootNavigator: true).pop();

      final tableData = (detail['table_data'] as List? ?? [])
          .map((r) => r as Map<String, dynamic>)
          .toList();

      showDialog(
        context: context,
        builder: (ctx) =>
            _SummaryDetailDialog(weekNumber: weekNumber, tableData: tableData),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      Toast.show(context, '加载详情失败: $e');
    }
  }
}

class _SummaryDetailDialog extends StatefulWidget {
  final int weekNumber;
  final List<Map<String, dynamic>> tableData;

  const _SummaryDetailDialog({
    required this.weekNumber,
    required this.tableData,
  });

  @override
  State<_SummaryDetailDialog> createState() => _SummaryDetailDialogState();
}

class _SummaryDetailDialogState extends State<_SummaryDetailDialog> {
  String? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final classes = <String>{};
    for (final row in widget.tableData) {
      classes.add(row['class_name'] as String);
    }
    final sortedClasses = classes.toList()..sort();

    final filteredData = _selectedClass == null
        ? widget.tableData
        : widget.tableData
              .where((r) => r['class_name'] == _selectedClass)
              .toList();

    return AlertDialog(
      title: Row(
        children: [
          Text('第${widget.weekNumber}周汇总'),
          const Spacer(),
          Text(
            '共${filteredData.length}人',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        height: 500,
        child: Column(
          children: [
            if (sortedClasses.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('班级筛选:', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedClass,
                        isExpanded: true,
                        hint: const Text('全部班级'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('全部班级'),
                          ),
                          ...sortedClasses.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedClass = v),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredData.isEmpty
                  ? const Center(child: Text('暂无异常记录'))
                  : ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final row = filteredData[index];
                        final late = row['late'] as int;
                        final absent = row['absent'] as int;
                        final total = row['total'] as int;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row['name'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        row['class_name'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (late > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            margin: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '迟到$late',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        if (absent > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '旷课$absent',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '累计: $total',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
