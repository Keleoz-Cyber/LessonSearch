import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/toast.dart';
import '../../../features/extension/presentation/submission_page.dart';
import '../data/records_repository.dart';
import '../../attendance/domain/models.dart';

class RecordsListPage extends ConsumerStatefulWidget {
  const RecordsListPage({super.key});

  @override
  ConsumerState<RecordsListPage> createState() => _RecordsListPageState();
}

class _RecordsListPageState extends ConsumerState<RecordsListPage> {
  List<TaskSummary> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(recordsRepositoryProvider);
    final summaries = await repo.getTaskSummaries();
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('查课记录')),
      body: LoadingOverlay(
        isLoading: _loading,
        child: _summaries.isEmpty && !_loading
            ? RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.6,
                      child: EmptyState.noRecord(),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final s = _summaries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _TaskCard(
                        summary: s,
                        onTap: () async {
                          await context.push('/records/${s.id}');
                          _load();
                        },
                        onDelete: () => _confirmDelete(s),
                        onResume: s.status == TaskStatus.inProgress
                            ? () => _resumeTask(s)
                            : null,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _resumeTask(TaskSummary summary) async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final task = await attendanceRepo.getTask(summary.id);
    if (task == null || !mounted) return;

    final studentRepo = ref.read(studentRepositoryProvider);
    final allClasses = await studentRepo.getClasses();
    final classNames = task.classIds.map((id) {
      final cls = allClasses.where((c) => c.id == id);
      return cls.isNotEmpty ? cls.first.displayName : '未知';
    }).toList();

    if (!mounted) return;

    final route = task.type == TaskType.rollCall
        ? '/roll-call/execute'
        : '/name-check/execute';

    await context.push(
      route,
      extra: {
        'classIds': task.classIds,
        'classNames': classNames,
        'gradeId': task.selectedGradeId ?? 0,
        'majorId': task.selectedMajorId ?? 0,
        'resumeTaskId': task.id,
      },
    );
    _load();
  }

  Future<void> _confirmDelete(TaskSummary summary) async {
    // 已经是放弃状态，无需再次操作
    if (summary.status == TaskStatus.abandoned) {
      Toast.show(context, '该记录已放弃');
      return;
    }

    // 检查是否已提交
    try {
      final submittedIds = await ref.read(submittedTaskIdsProvider.future);
      if (submittedIds.contains(summary.id)) {
        Toast.show(context, '该记录已提交审核，无法放弃。如需放弃，请先撤销提交。');
        return;
      }
    } catch (_) {
      // 获取失败时忽略检查
    }

    // 检查是否有同步失败数据
    final hasSyncFailed = ref.read(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.when(
      data: (failed) => failed,
      loading: () => false,
      error: (_, __) => false,
    );
    if (isSyncFailed) {
      Toast.show(context, '存在同步失败数据，请先到同步问题详情处理后再操作');
      return;
    }

    final c = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认放弃 ${summary.classNames.join("、")} 的${summary.typeLabel}记录？',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: c.stateWarning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.normal),
                border: Border.all(
                  color: c.stateWarning.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: c.stateWarning,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '放弃后该记录不会参与名单提交，但数据仍保留用于查看。',
                      style: AppTextStyles.sm.copyWith(color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: c.stateDanger),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final repo = ref.read(recordsRepositoryProvider);
      await repo.deleteTask(summary.id);

      // 放弃后刷新名单提交页的 provider，避免已放弃任务仍显示
      ref.invalidate(weekNameCheckTasksProvider);
      ref.invalidate(submittedTaskIdsProvider);
      ref.invalidate(mySubmissionsProvider);

      _load();
    }
  }
}

class _TaskCard extends StatelessWidget {
  final TaskSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onResume;

  const _TaskCard({
    required this.summary,
    required this.onTap,
    required this.onDelete,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final date = summary.createdAt.toString().substring(0, 16);
    final isAbandoned = summary.status == TaskStatus.abandoned;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      label: summary.typeLabel,
                      variant: summary.type == TaskType.rollCall
                          ? StatusPillVariant.info
                          : StatusPillVariant.success,
                    ),
                    if (isAbandoned)
                      const StatusPill.danger(label: '已放弃'),
                    if (summary.status == TaskStatus.inProgress)
                      const StatusPill.info(label: '进行中'),
                    if (summary.status == TaskStatus.completed &&
                        summary.type == TaskType.rollCall)
                      const StatusPill.success(label: '已完成'),
                  ],
                ),
              ),
              if (!isAbandoned)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: c.textTertiary,
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: '放弃',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.classNames.join('、'),
            style: AppTextStyles.h3.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '共${summary.totalStudents}人 · '
            '${summary.type == TaskType.rollCall ? "已点${summary.presentCount + summary.lateCount} 未点${summary.absentCount + summary.leaveCount + summary.otherCount}" : "到${summary.presentCount} 缺${summary.absentCount} 迟${summary.lateCount} 假${summary.leaveCount} 他${summary.otherCount}"}',
            style: AppTextStyles.sm.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            date,
            style: AppTextStyles.withTabular(
              AppTextStyles.xs,
            ).copyWith(color: c.textTertiary),
          ),
          if (onResume != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              label: '继续',
              onPressed: onResume,
              size: AppButtonSize.md,
              fullWidth: true,
              leadingIcon: Icons.play_arrow_rounded,
            ),
          ],
        ],
      ),
    );
  }
}
