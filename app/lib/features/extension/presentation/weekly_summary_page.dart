import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/sync/sync_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/app_notice_box.dart';
import '../../../shared/design_system/widgets/app_stat_chip.dart';
import '../../../shared/design_system/widgets/app_stat_tile.dart';
import '../../../shared/design_system/widgets/skeleton.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/submission_service.dart';

final currentWeekProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/week/current');
  return res.data as Map<String, dynamic>;
});

final pendingSubmissionsProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  weekNumber,
) {
  return ref
      .watch(submissionServiceProvider)
      .getPendingSubmissions(weekNumber: weekNumber);
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

final reviewedSubmissionsProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  weekNumber,
) {
  return ref
      .watch(submissionServiceProvider)
      .getReviewedSubmissions(weekNumber: weekNumber);
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

    // 进入页面时刷新职务状态
    Future.microtask(() {
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
      final weekData = ref.read(currentWeekProvider).valueOrNull;
      if (weekData != null) {
        final weekNumber = weekData['week_number'] as int;
        ref.invalidate(pendingSubmissionsProvider(weekNumber));
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        ref.invalidate(weekSummaryProvider(weekNumber));
        ref.invalidate(myDutyProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = ref.watch(authServiceProvider);
    final currentWeekAsync = ref.watch(currentWeekProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
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
        loading: () => const LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: c.textTertiary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '加载失败',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$e',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton.primary(
                  label: '重试',
                  onPressed: () => ref.invalidate(currentWeekProvider),
                  leadingIcon: Icons.refresh,
                ),
              ],
            ),
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
    // pendingSubmissions 和 submissionStatus 是管理员接口，member 不请求
    final pendingAsync = isAdmin
        ? ref.watch(pendingSubmissionsProvider(weekNumber))
        : const AsyncValue<List<dynamic>>.loading();
    final submissionStatusAsync = isAdmin
        ? ref.watch(weekSubmissionStatusProvider(weekNumber))
        : const AsyncValue<Map<String, dynamic>>.loading();
    final weekSummaryAsync = ref.watch(weekSummaryProvider(weekNumber));
    final exportStatusAsync = ref.watch(exportStatusProvider(weekNumber));
    final startDate = DateTime.parse(weekData['start_date'] as String);
    final endDate = DateTime.parse(weekData['end_date'] as String);
    final semesterName = weekData['semester_name'] as String?;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingSubmissionsProvider(weekNumber));
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        ref.invalidate(weekSummaryProvider(weekNumber));
        ref.invalidate(exportStatusProvider(weekNumber));
        ref.invalidate(reviewedSubmissionsProvider(weekNumber));
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
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: c.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: c.brandPrimary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 $weekNumber 周',
                      style: AppTextStyles.display.copyWith(
                        color: c.onBrand,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (semesterName != null)
                      Text(
                        semesterName,
                        style: AppTextStyles.sm.copyWith(
                          color: c.onBrand.withValues(alpha: 0.90),
                        ),
                      ),
                    Text(
                      '${DateFormat('M月d日').format(startDate)} - ${DateFormat('M月d日').format(endDate)}',
                      style: AppTextStyles.withTabular(AppTextStyles.sm)
                          .copyWith(color: c.onBrand.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              exportStatusAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (status) {
                  final isPublished =
                      status['is_published'] as bool? ?? false;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.onBrand.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: c.onBrand.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPublished
                              ? Icons.check_circle
                              : Icons.schedule_outlined,
                          size: 14,
                          color: c.onBrand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPublished ? '已发布' : '未发布',
                          style: AppTextStyles.xs.copyWith(
                            color: c.onBrand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
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
    final c = context.colors;
    final reviewedAsync = ref.watch(reviewedSubmissionsProvider(weekNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        weekSummaryAsync.when(
          loading: () => const SkeletonCard(),
          error: (e, _) => AppNoticeBox(
            color: c.stateDanger,
            icon: Icons.error_outline,
            title: '加载汇总统计失败',
            body: '$e',
          ),
          data: (summary) =>
              _buildSummaryPreviewCard(context, ref, summary, weekNumber),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton.gradient(
          label: '导出并发布本周汇总',
          leadingIcon: Icons.cloud_download_outlined,
          fullWidth: true,
          onPressed: () => _showExportDialog(context, ref, weekNumber),
        ),
        const SizedBox(height: AppSpacing.lg),
        submissionStatusAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppNoticeBox(
            color: c.stateDanger,
            icon: Icons.error_outline,
            title: '加载提交状态失败',
            body: '$e',
          ),
          data: (status) => _buildSubmissionStatusCard(context, status),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeader(title: '待审核提交'),
        pendingAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Padding(padding: EdgeInsets.only(bottom: AppSpacing.md), child: SkeletonCard()),
                SkeletonCard(),
              ],
            ),
          ),
          error: (e, _) => AppNoticeBox(
            color: c.stateDanger,
            icon: Icons.error_outline,
            title: '加载失败',
            body: '$e',
          ),
          data: (pending) {
            if (pending.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 40,
                        color: c.stateSuccess,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '暂无待审核提交',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
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
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeader(title: '已审核记录'),
        reviewedAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: SkeletonCard(),
          ),
          error: (e, _) => AppNoticeBox(
            color: c.stateDanger,
            icon: Icons.error_outline,
            title: '加载失败',
            body: '$e',
          ),
          data: (reviewed) {
            if (reviewed.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 40,
                        color: c.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '暂无已审核记录',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: reviewed
                  .map(
                    (s) => _ReviewedSubmissionCard(
                      submission: s,
                      weekNumber: weekNumber,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubmissionStatusCard(
    BuildContext context,
    Map<String, dynamic> status,
  ) {
    final c = context.colors;
    final totalDuty = status['total_duty'] as int? ?? 0;
    final submittedCount = status['submitted_count'] as int? ?? 0;
    final notSubmittedCount = status['not_submitted_count'] as int? ?? 0;
    final submittedMembers = status['submitted_members'] as List? ?? [];
    final notSubmittedMembers = status['not_submitted_members'] as List? ?? [];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '提交状态',
                  style:
                      AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
              ),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  AppStatChip(
                    label: '应交',
                    count: totalDuty,
                    color: c.brandPrimary,
                    compact: true,
                  ),
                  AppStatChip(
                    label: '已交',
                    count: submittedCount,
                    color: c.stateSuccess,
                    compact: true,
                  ),
                  AppStatChip(
                    label: '未交',
                    count: notSubmittedCount,
                    color: c.stateWarning,
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
          if (submittedMembers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.stateSuccess,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '已提交',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...submittedMembers.map(
              (m) => _buildMemberStatusItem(context, m, true),
            ),
          ],
          if (notSubmittedMembers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.stateWarning,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '未提交',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...notSubmittedMembers.map(
              (m) => _buildMemberStatusItem(context, m, false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberStatusItem(
    BuildContext context,
    Map<String, dynamic> member,
    bool submitted,
  ) {
    final c = context.colors;
    final userName = member['user_name'] as String? ?? '未知';
    final pendingCount = member['pending_count'] as int? ?? 0;
    final approvedCount = member['approved_count'] as int? ?? 0;
    final rejectedCount = member['rejected_count'] as int? ?? 0;
    final submissionCount = member['submission_count'] as int? ?? 0;

    String statusText;
    Color statusColor;
    if (submitted) {
      if (pendingCount > 0) {
        statusText = '$submissionCount 个 · $pendingCount 待审核';
        statusColor = c.stateWarning;
      } else if (rejectedCount > 0) {
        statusText = '$submissionCount 个 · $rejectedCount 已拒绝';
        statusColor = c.stateDanger;
      } else {
        statusText = '$approvedCount 个 · 已通过';
        statusColor = c.stateSuccess;
      }
    } else {
      statusText = '未提交';
      statusColor = c.stateWarning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            submitted ? Icons.check_circle : Icons.schedule_outlined,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              userName,
              style: AppTextStyles.sm.copyWith(color: c.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              statusText,
              style: AppTextStyles.xs.copyWith(color: statusColor),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
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
    final c = context.colors;
    final lateCount = summary['late_count'] as int? ?? 0;
    final absentCount = summary['absent_count'] as int? ?? 0;
    final leaveCount = summary['leave_count'] as int? ?? 0;
    final otherCount = summary['other_count'] as int? ?? 0;
    final approvedCount = summary['approved_count'] as int? ?? 0;

    return AppCard(
      onTap: () => _showSummaryDetailDialog(context, ref, weekNumber),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined,
                  size: 18, color: c.brandPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '汇总预览',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right, color: c.textTertiary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppStatChip(label: '迟到', count: lateCount, color: c.stateWarning),
              AppStatChip(label: '缺勤', count: absentCount, color: c.stateDanger),
              AppStatChip(label: '请假', count: leaveCount, color: c.stateInfo),
              AppStatChip(label: '其他', count: otherCount, color: c.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.verified_outlined,
                  size: 14, color: c.stateSuccess),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '已审核提交 $approvedCount',
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              Text(
                '查看详细名单',
                style: AppTextStyles.sm.copyWith(color: c.brandPrimary),
              ),
            ],
          ),
        ],
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

  Widget _buildMemberSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> exportStatusAsync,
    AsyncValue<Map<String, dynamic>> weekSummaryAsync,
    int weekNumber,
  ) {
    final c = context.colors;
    final myDutyAsync = ref.watch(myDutyProvider);

    return exportStatusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppNoticeBox(
        color: c.stateDanger,
        icon: Icons.error_outline,
        title: '加载发布状态失败',
        body: '$e',
      ),
      data: (exportStatus) {
        final isPublished = exportStatus['is_published'] as bool? ?? false;

        if (!isPublished) {
          return Column(
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: c.stateWarning.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.schedule_outlined,
                          size: 28,
                          color: c.stateWarning,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '本周汇总尚未发布',
                        style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '请等待管理员导出后查看',
                        style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              myDutyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppNoticeBox(
                  color: c.stateDanger,
                  icon: Icons.error_outline,
                  title: '加载职务状态失败',
                ),
                data: (duty) => _buildDutyStatusCard(context, duty),
              ),
            ],
          );
        }

        return weekSummaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => AppNoticeBox(
            color: c.stateDanger,
            icon: Icons.error_outline,
            title: '加载汇总数据失败',
            body: '$e',
          ),
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
    final c = context.colors;
    final hasDuty = duty['has_duty'] as bool? ?? false;
    if (!hasDuty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 36, color: c.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                '您没有被分配查课职务',
                style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '无需提交考勤记录',
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return EmptyStateCard.noPending();
  }

  Widget _buildPublishedSection(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> summary,
    Map<String, dynamic> exportStatus,
    int weekNumber,
  ) {
    final c = context.colors;
    final lateCount = summary['late_count'] as int? ?? 0;
    final absentCount = summary['absent_count'] as int? ?? 0;
    final approvedCount = summary['approved_count'] as int? ?? 0;
    final exportedAt = exportStatus['exported_at'] as String?;
    final exportedByName = exportStatus['exported_by_name'] as String?;
    final total = (lateCount / 2).floor() + absentCount;

    return AppCard(
      onTap: () => _showSummaryDetailDialog(context, ref, weekNumber),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.stateSuccess.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: c.stateSuccess,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '本周汇总已发布',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right, color: c.textTertiary, size: 20),
            ],
          ),
          if (exportedByName != null || exportedAt != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (exportedByName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '导出人 · $exportedByName',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              ),
            if (exportedAt != null)
              Text(
                '导出时间 · ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(exportedAt))}',
                style: AppTextStyles.withTabular(AppTextStyles.sm)
                    .copyWith(color: c.textTertiary),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: c.borderSubtle),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '本周统计',
            style: AppTextStyles.bodyMedium.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: '迟到/早退',
                  count: lateCount,
                  color: c.stateWarning,
                  icon: Icons.access_time,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppStatTile(
                  label: '旷课',
                  count: absentCount,
                  color: c.stateDanger,
                  icon: Icons.event_busy,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppStatTile(
                  label: '已审核',
                  count: approvedCount,
                  color: c.stateSuccess,
                  icon: Icons.verified_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.bgMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined,
                    size: 18, color: c.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '累计违纪',
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                ),
                Text(
                  '$total 次',
                  style: AppTextStyles.withTabular(AppTextStyles.h3).copyWith(
                    color: total > 0 ? c.stateDanger : c.stateSuccess,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              '点击查看详细名单',
              style: AppTextStyles.sm.copyWith(color: c.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog(
    BuildContext context,
    WidgetRef ref,
    int weekNumber,
  ) async {
    // 导出前检查是否有未同步数据（pending + failed）
    final issueCountAsync = ref.read(syncIssueCountProvider);
    final issueCount = issueCountAsync.valueOrNull ?? 0;
    final syncState = ref.read(syncStateProvider);

    if (issueCount > 0 || syncState == SyncState.syncing) {
      final shouldSync = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法导出'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                syncState == SyncState.syncing
                    ? '正在同步数据中，请等待同步完成后再导出。'
                    : '有 $issueCount 条同步问题未处理，导出前请先完成同步，确保数据完整。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('立即同步'),
            ),
          ],
        ),
      );

      if (shouldSync == true) {
        await ref.read(syncServiceProvider).syncNow();
        // 同步后再试一次
        if (context.mounted) {
          _showExportDialog(context, ref, weekNumber);
        }
      }
      return;
    }

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
      final filename = '第$weekNumber周考勤表.xlsx';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], subject: filename);

      ref.invalidate(pendingSubmissionsProvider(weekNumber));
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
    final c = context.colors;
    final userName =
        submission['user_name'] ?? submission['user_email'] ?? '未知';
    final submittedAt = DateTime.parse(submission['submitted_at'] as String);
    final taskCount = submission['task_count'];
    final recordCount = submission['record_count'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => _showDetailDialog(context, ref),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(submittedAt),
                        style: AppTextStyles.withTabular(AppTextStyles.xs)
                            .copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const StatusPill.warning(
                  label: '待审核',
                  icon: Icons.schedule_outlined,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 14, color: c.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$taskCount 个任务',
                    style: AppTextStyles.xs.copyWith(color: c.textSecondary),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: c.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Text(
                    '$recordCount 条记录',
                    style: AppTextStyles.xs.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(builder: (ctx, constraints) {
              final compact = constraints.maxWidth < 320;
              final actions = [
                Expanded(
                  child: AppButton.secondary(
                    label: '拒绝',
                    leadingIcon: Icons.close,
                    onPressed: () => _showRejectDialog(context, ref),
                  ),
                ),
                SizedBox(width: compact ? 0 : AppSpacing.md,
                    height: compact ? AppSpacing.sm : 0),
                Expanded(
                  child: AppButton.primary(
                    label: '通过',
                    leadingIcon: Icons.check,
                    onPressed: () => _approve(context, ref),
                  ),
                ),
              ];
              return compact
                  ? Column(children: actions.whereType<Widget>().toList())
                  : Row(children: actions.whereType<Widget>().toList());
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetailDialog(BuildContext context, WidgetRef ref) async {
    final submissionId = submission['id'] as int;
    final submissionStatus = submission['status'] as String;

    await showDialog(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.fact_check_outlined,
                  size: 20, color: c.brandPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '审核详情 · ${submission['user_name'] ?? '未知'}',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: submissionStatus == 'cancelled'
                ? _CancelledNotice(c: c)
                : FutureBuilder<Map<String, dynamic>>(
                    future: ref
                        .read(submissionServiceProvider)
                        .getSubmissionRecords(submissionId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return AppNoticeBox(
                          color: c.stateDanger,
                          icon: Icons.error_outline,
                          title: '加载失败',
                          body: '${snapshot.error}',
                        );
                      }

                      final data = snapshot.data!;
                      final status = data['status'] as String?;
                      if (status == 'cancelled') {
                        return _CancelledNotice(c: c);
                      }

                      final records = data['records'] as List? ?? [];
                      final lateCount = data['late_count'] as int? ?? 0;
                      final absentCount = data['absent_count'] as int? ?? 0;
                      final leaveCount = data['leave_count'] as int? ?? 0;
                      final otherCount = data['other_count'] as int? ?? 0;
                      final recordCount = records.length;

                      final lateRecords = records
                          .where((r) => r['status'] == 'late')
                          .toList();
                      final absentRecords = records
                          .where((r) => r['status'] == 'absent')
                          .toList();
                      final leaveRecords = records
                          .where((r) => r['status'] == 'leave')
                          .toList();
                      final otherRecords = records
                          .where((r) => r['status'] == 'other')
                          .toList();

                      final isRejected = status == 'rejected';

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isRejected) ...[
                              AppNoticeBox(
                                color: c.stateDanger,
                                icon: Icons.cancel,
                                title: '已拒绝',
                                body: submission['reviewer_name'] != null
                                    ? '审核人 · ${submission['reviewer_name']}'
                                    : null,
                              ),
                              if (submission['review_note'] != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm),
                                  child: Text(
                                    '拒绝原因 · ${submission['review_note']}',
                                    style: AppTextStyles.sm
                                        .copyWith(color: c.stateDanger),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            if (recordCount == 0)
                              EmptyState.noLinkedRecords()
                            else if (lateCount + absentCount + leaveCount +
                                    otherCount ==
                                0)
                              EmptyState.noAbnormalRecords()
                            else ...[
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  AppStatChip(
                                      label: '迟到',
                                      count: lateCount,
                                      color: c.stateWarning),
                                  AppStatChip(
                                      label: '缺勤',
                                      count: absentCount,
                                      color: c.stateDanger),
                                  AppStatChip(
                                      label: '请假',
                                      count: leaveCount,
                                      color: c.stateInfo),
                                  AppStatChip(
                                      label: '其他',
                                      count: otherCount,
                                      color: c.textTertiary),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (absentRecords.isNotEmpty)
                                _RecordListPreview(
                                    label: '缺勤',
                                    records: absentRecords,
                                    color: c.stateDanger,
                                    max: 999),
                              if (lateRecords.isNotEmpty)
                                _RecordListPreview(
                                    label: '迟到',
                                    records: lateRecords,
                                    color: c.stateWarning,
                                    max: 999),
                              if (leaveRecords.isNotEmpty)
                                _RecordListPreview(
                                    label: '请假',
                                    records: leaveRecords,
                                    color: c.stateInfo,
                                    max: 999),
                              if (otherRecords.isNotEmpty)
                                _RecordListPreview(
                                    label: '其他',
                                    records: otherRecords,
                                    color: c.textTertiary,
                                    max: 999),
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
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRejectDialog(context, ref);
                },
                style: TextButton.styleFrom(foregroundColor: c.stateDanger),
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
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showReviewConfirmDialog(context, ref, isApprove: true);
    if (!confirmed) return;

    try {
      final service = ref.read(submissionServiceProvider);
      await service.approveSubmission(submission['id']);
      ref.invalidate(pendingSubmissionsProvider(weekNumber));
      ref.invalidate(weekSummaryProvider(weekNumber));
      ref.invalidate(weekSubmissionStatusProvider(weekNumber));
      ref.invalidate(reviewedSubmissionsProvider(weekNumber));
      Toast.show(context, '审核通过');
    } on DioException catch (e) {
      final message = e.response?.data['detail'] ?? '操作失败';
      Toast.show(context, message);
    } catch (e) {
      Toast.show(context, '操作失败: $e');
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    // 先显示摘要确认
    final confirmed = await _showReviewConfirmDialog(context, ref, isApprove: false);
    if (!confirmed) return;

    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_note, size: 20, color: c.stateDanger),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '拒绝理由',
                style: AppTextStyles.h3.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入拒绝理由',
              hintStyle:
                  AppTextStyles.sm.copyWith(color: c.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: c.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: c.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide:
                    BorderSide(color: c.brandPrimary, width: 1.5),
              ),
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
              style: FilledButton.styleFrom(
                backgroundColor: c.stateDanger,
                foregroundColor: c.onBrand,
              ),
              child: const Text('确认拒绝'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final note = controller.text.trim();
      if (note.isEmpty) {
        Toast.show(context, '请输入拒绝理由');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.dispose();
        });
        return;
      }
      try {
        final service = ref.read(submissionServiceProvider);
        await service.rejectSubmission(submission['id'], note);
        ref.invalidate(pendingSubmissionsProvider(weekNumber));
        ref.invalidate(weekSubmissionStatusProvider(weekNumber));
        ref.invalidate(reviewedSubmissionsProvider(weekNumber));
        Toast.show(context, '已拒绝');
      } on DioException catch (e) {
        final message = e.response?.data['detail'] ?? '操作失败';
        Toast.show(context, message);
      } catch (e) {
        Toast.show(context, '操作失败: $e');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  /// 审核前确认对话框，展示提交摘要信息
  Future<bool> _showReviewConfirmDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isApprove,
  }) async {
    final submissionId = submission['id'] as int;

    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在加载提交详情...'),
          ],
        ),
      ),
    );

    try {
      final data = await ref
          .read(submissionServiceProvider)
          .getSubmissionRecords(submissionId);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // 检查是否已被撤销
      final status = data['status'] as String?;
      if (status == 'cancelled') {
        if (context.mounted) Toast.show(context, '该提交已被撤销');
        return false;
      }

      if (!context.mounted) return false;

      final records = data['records'] as List? ?? [];
      final lateCount = data['late_count'] as int? ?? 0;
      final absentCount = data['absent_count'] as int? ?? 0;
      final leaveCount = data['leave_count'] as int? ?? 0;
      final otherCount = data['other_count'] as int? ?? 0;
      final classNames = submission['class_names'] as String? ?? '';
      final userName = submission['user_name'] ?? submission['user_email'] ?? '未知';
      final submittedAt = DateTime.parse(submission['submitted_at'] as String);

      // 分类记录
      final absentRecords = records.where((r) => r['status'] == 'absent').toList();
      final lateRecords = records.where((r) => r['status'] == 'late').toList();
      final leaveRecords = records.where((r) => r['status'] == 'leave').toList();
      final otherRecords = records.where((r) => r['status'] == 'other').toList();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = ctx.colors;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isApprove ? Icons.check_circle_outline : Icons.warning_amber,
                  size: 20,
                  color: isApprove ? c.stateSuccess : c.stateDanger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isApprove ? '确认通过' : '确认拒绝',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow(c, '提交人', userName),
                    _buildInfoRow(c, '提交时间',
                        DateFormat('yyyy-MM-dd HH:mm').format(submittedAt)),
                    if (classNames.isNotEmpty)
                      _buildInfoRow(c, '班级', classNames),
                    _buildInfoRow(c, '记录数量', '${records.length} 条'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      child: Container(height: 1, color: c.borderSubtle),
                    ),
                    Text(
                      '异常统计',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppStatChip(
                            label: '迟到',
                            count: lateCount,
                            color: c.stateWarning),
                        AppStatChip(
                            label: '缺勤',
                            count: absentCount,
                            color: c.stateDanger),
                        AppStatChip(
                            label: '请假',
                            count: leaveCount,
                            color: c.stateInfo),
                        AppStatChip(
                            label: '其他',
                            count: otherCount,
                            color: c.textTertiary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (absentRecords.isNotEmpty)
                      _RecordListPreview(
                          label: '缺勤',
                          records: absentRecords,
                          color: c.stateDanger),
                    if (lateRecords.isNotEmpty)
                      _RecordListPreview(
                          label: '迟到',
                          records: lateRecords,
                          color: c.stateWarning),
                    if (leaveRecords.isNotEmpty)
                      _RecordListPreview(
                          label: '请假',
                          records: leaveRecords,
                          color: c.stateInfo),
                    if (otherRecords.isNotEmpty)
                      _RecordListPreview(
                          label: '其他',
                          records: otherRecords,
                          color: c.textTertiary),
                    const SizedBox(height: AppSpacing.sm),
                    AppNoticeBox(
                      color: isApprove ? c.stateSuccess : c.stateDanger,
                      icon: isApprove
                          ? Icons.check_circle_outline
                          : Icons.warning_amber,
                      title: isApprove ? '即将通过此提交' : '即将拒绝此提交',
                      body: isApprove
                          ? '通过后数据将计入周汇总。'
                          : '拒绝后成员可以修改后重新提交。',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isApprove ? c.stateSuccess : c.stateDanger,
                  foregroundColor: c.onBrand,
                ),
                child: Text(isApprove ? '确认通过' : '确认拒绝'),
              ),
            ],
          );
        },
      );

      return confirmed == true;
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) Toast.show(context, '加载详情失败: $e');
      return false;
    }
  }

  Widget _buildInfoRow(AppColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: AppTextStyles.sm.copyWith(color: c.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.sm.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewedSubmissionCard extends ConsumerWidget {
  final Map<String, dynamic> submission;
  final int weekNumber;

  const _ReviewedSubmissionCard({
    required this.submission,
    required this.weekNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final userName =
        submission['user_name'] ?? submission['user_email'] ?? '未知';
    final reviewerName = submission['reviewer_name'] ?? '未知';
    final reviewTime = submission['review_time'] != null
        ? DateTime.parse(submission['review_time'] as String)
        : null;
    final submittedAt = DateTime.parse(submission['submitted_at'] as String);
    final status = submission['status'] as String;
    final isApproved = status == 'approved';
    final taskCount = submission['task_count'];
    final recordCount = submission['record_count'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => _showDetailDialog(context, ref),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '提交于 ${DateFormat('yyyy-MM-dd HH:mm').format(submittedAt)}',
                        style: AppTextStyles.withTabular(AppTextStyles.xs)
                            .copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                isApproved
                    ? const StatusPill.success(
                        label: '已通过',
                        icon: Icons.check_circle,
                      )
                    : const StatusPill.danger(
                        label: '已拒绝',
                        icon: Icons.cancel,
                      ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: c.bgMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 14, color: c.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$taskCount 个任务',
                    style: AppTextStyles.xs.copyWith(color: c.textSecondary),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: c.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Text(
                    '$recordCount 条记录',
                    style: AppTextStyles.xs.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _MetaItem(
                  icon: Icons.person_outline,
                  text: '$reviewerName',
                  color: c.textSecondary,
                ),
                if (reviewTime != null)
                  _MetaItem(
                    icon: Icons.schedule_outlined,
                    text: DateFormat('yyyy-MM-dd HH:mm').format(reviewTime),
                    color: c.textTertiary,
                    tabular: true,
                  ),
              ],
            ),
            if (!isApproved && submission['review_note'] != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppNoticeBox(
                color: c.stateDanger,
                icon: Icons.message_outlined,
                title: '拒绝理由',
                body: '${submission['review_note']}',
              ),
            ],
          ],
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
            Text('正在加载...'),
          ],
        ),
      ),
    );

    try {
      final data = await ref
          .read(submissionServiceProvider)
          .getSubmissionRecords(submissionId);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final records = data['records'] as List? ?? [];
      final lateCount = data['late_count'] as int? ?? 0;
      final absentCount = data['absent_count'] as int? ?? 0;
      final leaveCount = data['leave_count'] as int? ?? 0;
      final otherCount = data['other_count'] as int? ?? 0;
      final recordCount = records.length;
      final submissionStatus = data['status'] as String?;
      final isRejected = submissionStatus == 'rejected';

      final lateRecords = records.where((r) => r['status'] == 'late').toList();
      final absentRecords =
          records.where((r) => r['status'] == 'absent').toList();
      final leaveRecords =
          records.where((r) => r['status'] == 'leave').toList();
      final otherRecords =
          records.where((r) => r['status'] == 'other').toList();

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          final c = ctx.colors;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.fact_check_outlined,
                    size: 20, color: c.brandPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '审核详情 · ${submission['user_name'] ?? '未知'}',
                    style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isRejected) ...[
                      AppNoticeBox(
                        color: c.stateDanger,
                        icon: Icons.cancel,
                        title: '已拒绝',
                        body: submission['reviewer_name'] != null
                            ? '审核人 · ${submission['reviewer_name']}'
                            : null,
                      ),
                      if (submission['review_note'] != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm),
                          child: Text(
                            '拒绝原因 · ${submission['review_note']}',
                            style: AppTextStyles.sm
                                .copyWith(color: c.stateDanger),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (recordCount == 0)
                      EmptyState.noLinkedRecords()
                    else if (lateCount + absentCount + leaveCount +
                            otherCount ==
                        0)
                      EmptyState.noAbnormalRecords()
                    else ...[
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppStatChip(
                              label: '迟到',
                              count: lateCount,
                              color: c.stateWarning),
                          AppStatChip(
                              label: '缺勤',
                              count: absentCount,
                              color: c.stateDanger),
                          AppStatChip(
                              label: '请假',
                              count: leaveCount,
                              color: c.stateInfo),
                          if (otherCount > 0)
                            AppStatChip(
                                label: '其他',
                                count: otherCount,
                                color: c.textTertiary),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (absentRecords.isNotEmpty)
                        _RecordListPreview(
                            label: '缺勤',
                            records: absentRecords,
                            color: c.stateDanger,
                            max: 999),
                      if (lateRecords.isNotEmpty)
                        _RecordListPreview(
                            label: '迟到',
                            records: lateRecords,
                            color: c.stateWarning,
                            max: 999),
                      if (leaveRecords.isNotEmpty)
                        _RecordListPreview(
                            label: '请假',
                            records: leaveRecords,
                            color: c.stateInfo,
                            max: 999),
                      if (otherRecords.isNotEmpty)
                        _RecordListPreview(
                            label: '其他',
                            records: otherRecords,
                            color: c.textTertiary,
                            max: 999),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Toast.show(context, '加载详情失败: $e');
    }
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool tabular;
  const _MetaItem({
    required this.icon,
    required this.text,
    required this.color,
    this.tabular = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = tabular
        ? AppTextStyles.withTabular(AppTextStyles.xs).copyWith(color: color)
        : AppTextStyles.xs.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
}

class _HistoryWeekTab extends ConsumerWidget {
  final int currentWeek;
  final bool isAdmin;

  const _HistoryWeekTab({required this.currentWeek, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final weeks = List.generate(currentWeek, (i) => currentWeek - i);
    return Container(
      color: c.bgCanvas,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: weeks.length,
        itemBuilder: (context, index) {
          final week = weeks[index];
          return RepaintBoundary(
            child: _HistoryWeekCard(
              weekNumber: week,
              currentWeek: currentWeek,
              isAdmin: isAdmin,
            ),
          );
        },
      ),
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
    final c = context.colors;
    final exportStatusAsync = ref.watch(exportStatusProvider(weekNumber));
    final weekSummaryAsync = isAdmin
        ? ref.watch(weekSummaryProvider(weekNumber))
        : const AsyncValue<Map<String, dynamic>>.loading();
    final isCurrent = weekNumber == currentWeek;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => _showWeekDetail(context, ref),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCurrent ? c.brandSubtle : c.bgMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isCurrent ? c.brandPrimary : c.borderSubtle,
                  width: isCurrent ? 1.2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$weekNumber',
                  style: AppTextStyles.withTabular(AppTextStyles.h3).copyWith(
                    color: isCurrent ? c.brandPrimary : c.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '第 $weekNumber 周',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.brandPrimary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '当前',
                            style: AppTextStyles.xs.copyWith(
                              color: c.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  exportStatusAsync.when(
                    loading: () => Text(
                      '加载状态…',
                      style:
                          AppTextStyles.xs.copyWith(color: c.textTertiary),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (status) {
                      final isPublished =
                          status['is_published'] as bool? ?? false;
                      return Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isPublished
                                      ? c.stateSuccess
                                      : c.textTertiary)
                                  .withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPublished
                                      ? Icons.check_circle
                                      : Icons.schedule_outlined,
                                  size: 11,
                                  color: isPublished
                                      ? c.stateSuccess
                                      : c.textTertiary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isPublished ? '已发布' : '未发布',
                                  style: AppTextStyles.xs.copyWith(
                                    color: isPublished
                                        ? c.stateSuccess
                                        : c.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isPublished)
                            weekSummaryAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (summary) {
                                final totalAbnormalStudents =
                                    summary['total_abnormal_students']
                                            as int? ??
                                        0;
                                if (totalAbnormalStudents > 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.stateDanger
                                          .withValues(alpha: 0.10),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                    ),
                                     child: Text(
                                       '异常 $totalAbnormalStudents 人',
                                       style: AppTextStyles.xs.copyWith(
                                         color: c.stateDanger,
                                         fontWeight: FontWeight.w600,
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
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right, color: c.textTertiary, size: 20),
          ],
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
      if (context.mounted) Toast.show(context, '该周汇总尚未发布');
      return;
    }

    if (!context.mounted) return;
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

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final tableData = (detail['table_data'] as List? ?? [])
          .map((r) => r as Map<String, dynamic>)
          .toList();

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) =>
            _SummaryDetailDialog(weekNumber: weekNumber, tableData: tableData),
      );
    } catch (e) {
      if (!context.mounted) return;
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
    final c = context.colors;
    final classes = <String>{};
    for (final row in widget.tableData) {
      final className = row['class_name'];
      if (className != null) {
        classes.add(className as String);
      }
    }
    final sortedClasses = classes.toList()..sort();

    final filteredData = _selectedClass == null
        ? widget.tableData
        : widget.tableData
              .where((r) => r['class_name'] == _selectedClass)
              .toList();

    final mq = MediaQuery.of(context);
    final dialogMaxWidth = mq.size.width * 0.92 < 520
        ? mq.size.width * 0.92
        : 520.0;

    return Dialog(
      backgroundColor: c.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogMaxWidth,
          maxHeight: mq.size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.brandSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.list_alt,
                      size: 18,
                      color: c.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第 ${widget.weekNumber} 周汇总',
                          style: AppTextStyles.h2
                              .copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '共 ${filteredData.length} 人',
                          style: AppTextStyles.sm
                              .copyWith(color: c.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: c.textSecondary),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            if (sortedClasses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.bgMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: 16, color: c.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '班级',
                        style: AppTextStyles.sm
                            .copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClass,
                            isExpanded: true,
                            isDense: true,
                            hint: Text(
                              '全部班级',
                              style: AppTextStyles.sm
                                  .copyWith(color: c.textPrimary),
                            ),
                            style: AppTextStyles.sm
                                .copyWith(color: c.textPrimary),
                            iconEnabledColor: c.textSecondary,
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  '全部班级',
                                  style: AppTextStyles.sm
                                      .copyWith(color: c.textPrimary),
                                ),
                              ),
                              ...sortedClasses.map(
                                (cls) => DropdownMenuItem(
                                  value: cls,
                                  child: Text(
                                    cls,
                                    style: AppTextStyles.sm
                                        .copyWith(color: c.textPrimary),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedClass = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(height: 1, color: c.borderSubtle),
            Flexible(
              child: filteredData.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl2),
                      child: EmptyState.noAbnormal(),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      itemCount: filteredData.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final row = filteredData[index];
                        final lateNum = (row['late'] as int?) ?? 0;
                        final absentNum = (row['absent'] as int?) ?? 0;
                        final leaveNum = (row['leave'] as int?) ?? 0;
                        final otherNum = (row['other'] as int?) ?? 0;
                        final total = (row['total'] as int?) ?? 0;
                        return RepaintBoundary(
                          child: _StudentRow(
                            index: index + 1,
                            name: (row['name'] as String?) ?? '未知',
                            className: (row['class_name'] as String?) ?? '',
                            late: lateNum,
                            absent: absentNum,
                            leave: leaveNum,
                            other: otherNum,
                            total: total,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final int index;
  final String name;
  final String className;
  final int late;
  final int absent;
  final int leave;
  final int other;
  final int total;

  const _StudentRow({
    required this.index,
    required this.name,
    required this.className,
    required this.late,
    required this.absent,
    required this.leave,
    required this.other,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasIssue = total > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: hasIssue ? c.stateDanger.withValues(alpha: 0.10) : c.bgMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                '$index',
                style: AppTextStyles.withTabular(AppTextStyles.xs).copyWith(
                  color: hasIssue ? c.stateDanger : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (className.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    className,
                    style: AppTextStyles.xs.copyWith(color: c.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  if (late > 0)
                    _MicroChip(
                        label: '迟$late', color: c.stateWarning),
                  if (absent > 0)
                    _MicroChip(
                        label: '缺$absent', color: c.stateDanger),
                  if (leave > 0)
                    _MicroChip(
                        label: '假$leave', color: c.stateInfo),
                  if (other > 0)
                    _MicroChip(
                        label: '其$other', color: c.textTertiary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '累计 $total',
                style: AppTextStyles.withTabular(AppTextStyles.sm).copyWith(
                  color: hasIssue ? c.stateDanger : c.stateSuccess,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MicroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTextStyles.xs.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =================== 共享 helper 区 ===================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h3.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordListPreview extends StatelessWidget {
  final String label;
  final List<dynamic> records;
  final Color color;
  final int max;

  const _RecordListPreview({
    required this.label,
    required this.records,
    required this.color,
    this.max = 5,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final previewCount = records.length > max ? max : records.length;
    final hasMore = records.length > max;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$label名单',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${records.length}人',
                style: AppTextStyles.xs.copyWith(color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...records.take(previewCount).map((r) => Padding(
                padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
                child: Text(
                  '${r['student_name']} · ${r['student_no']} · ${r['class_name']}',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 2),
              child: Text(
                '...等 ${records.length - previewCount} 人',
                style: AppTextStyles.xs.copyWith(color: c.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelledNotice extends StatelessWidget {
  final AppColors c;
  const _CancelledNotice({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, size: 40, color: c.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            '该提交已被撤销',
            style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '成员已撤销此提交，无法审核',
            style: AppTextStyles.sm.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
