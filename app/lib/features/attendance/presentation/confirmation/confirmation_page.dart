import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/app_card.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/design_system/widgets/status_pill.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../attendance/domain/models.dart';

/// 记名确认页：展示异常名单（未到/请假/其他），按班级分组
class ConfirmationPage extends ConsumerWidget {
  const ConfirmationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nameCheckProvider);
    final task = state.task;

    if (task == null) {
      return Scaffold(
        backgroundColor: context.colors.bgCanvas,
        appBar: AppBar(title: const Text('确认名单')),
        body: Center(
          child: Text(
            '无任务数据',
            style: AppTextStyles.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    // 收集异常记录，按班级分组
    final abnormalByClass = <String, List<_AbnormalEntry>>{};
    for (final cls in state.classes) {
      final students = state.studentsByClass[cls.id] ?? [];
      final abnormals = students
          .where(
            (s) =>
                s.status != AttendanceStatus.present &&
                s.status != AttendanceStatus.pending,
          )
          .map(
            (s) => _AbnormalEntry(
              name: s.student.name,
              studentNo: s.student.studentNo,
              status: s.status,
              remark: s.remark,
            ),
          )
          .toList();
      if (abnormals.isNotEmpty) {
        abnormalByClass[cls.displayName] = abnormals;
      }
    }

    final totalStudents = state.totalStudents;
    final abnormalCount = abnormalByClass.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );

    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(nameCheckProvider.notifier).resumeEditing();
        context.pop();
      },
      child: Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: AppBar(title: const Text('确认名单')),
        body: Column(
          children: [
            _SummaryHeader(
              totalStudents: totalStudents,
              abnormalCount: abnormalCount,
            ),
            Expanded(
              child: abnormalByClass.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: EmptyStateCard.noAbnormal(),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: abnormalByClass.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                          ),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: AppTextStyles.h3.copyWith(
                                          color: c.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '${entry.value.length} 人异常',
                                      style: AppTextStyles.sm.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ...entry.value.map(
                                  (e) => _AbnormalRow(entry: e),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            BottomActionBar(
              primary: AppButton.gradient(
                label: '确认名单',
                onPressed: () {
                  context.push('/text-gen', extra: {'taskId': task.id});
                },
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
              secondary: AppButton.secondary(
                label: '重新编辑',
                onPressed: () {
                  ref.read(nameCheckProvider.notifier).resumeEditing();
                  context.pop();
                },
                size: AppButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部摘要信息条：总人数 + 异常人数
class _SummaryHeader extends StatelessWidget {
  final int totalStudents;
  final int abnormalCount;

  const _SummaryHeader({
    required this.totalStudents,
    required this.abnormalCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allOk = abnormalCount == 0;
    final tintColor = allOk ? c.stateSuccess : c.stateWarning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: tintColor.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            allOk ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: tintColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              allOk
                  ? '共 $totalStudents 人，全部到齐'
                  : '共 $totalStudents 人，异常 $abnormalCount 人',
              style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbnormalEntry {
  final String name;
  final String studentNo;
  final AttendanceStatus status;
  final String? remark;

  const _AbnormalEntry({
    required this.name,
    required this.studentNo,
    required this.status,
    this.remark,
  });

  String get statusLabel => switch (status) {
    AttendanceStatus.absent => '缺勤',
    AttendanceStatus.late_ => '迟到',
    AttendanceStatus.leave => '请假',
    AttendanceStatus.other => remark ?? '其他',
    _ => '',
  };

  StatusPillVariant get pillVariant => switch (status) {
    AttendanceStatus.absent => StatusPillVariant.danger,
    AttendanceStatus.late_ => StatusPillVariant.warning,
    AttendanceStatus.leave => StatusPillVariant.info,
    AttendanceStatus.other => StatusPillVariant.neutral,
    _ => StatusPillVariant.neutral,
  };
}

class _AbnormalRow extends StatelessWidget {
  final _AbnormalEntry entry;

  const _AbnormalRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.name,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 4,
            child: Text(
              entry.studentNo,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.withTabular(
                AppTextStyles.sm,
              ).copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusPill(label: entry.statusLabel, variant: entry.pillVariant),
        ],
      ),
    );
  }
}
