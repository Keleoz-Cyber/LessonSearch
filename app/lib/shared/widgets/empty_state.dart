import 'package:flutter/material.dart';

import '../design_system/colors.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';
import '../design_system/widgets/app_card.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final Color? color;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.color,
  });

  factory EmptyState.noTask() => EmptyState(
    icon: Icons.assignment_outlined,
    message: '暂无考勤任务',
    hint: '点击上方按钮开始点名或记名',
  );

  factory EmptyState.noRecord() =>
      EmptyState(icon: Icons.history, message: '暂无查课记录');

  factory EmptyState.noSubmission() =>
      EmptyState(icon: Icons.send_outlined, message: '暂无提交记录');

  factory EmptyState.noPending() => EmptyState(
    icon: Icons.check_circle_outline,
    message: '暂无待审核提交',
    color: Colors.green,
  );

  factory EmptyState.noReviewed() =>
      EmptyState(icon: Icons.history, message: '暂无已审核记录');

  factory EmptyState.noAbnormal() => EmptyState(
    icon: Icons.check_circle,
    message: '全部到齐，无异常记录',
    color: Colors.green,
  );

  /// 提交有记录但无异常学生
  factory EmptyState.noAbnormalRecords() => EmptyState(
    icon: Icons.check_circle_outline,
    message: '本次提交无异常学生，全部到齐。',
    color: Colors.green,
  );

  /// 提交没有关联学生记录（record_count == 0）
  factory EmptyState.noLinkedRecords() => EmptyState(
    icon: Icons.warning_amber_rounded,
    message: '该提交没有关联到学生记录',
    hint: '可能是旧版本或同步异常产生的记录。建议重新提交一份正常记录，或联系管理员确认。',
    color: Colors.orange,
  );

  factory EmptyState.noStudents() =>
      EmptyState(icon: Icons.people_outline, message: '暂无学生数据');

  factory EmptyState.noClass() =>
      EmptyState(icon: Icons.class_outlined, message: '暂无班级数据');

  factory EmptyState.noData() =>
      EmptyState(icon: Icons.inbox_outlined, message: '暂无数据');

  factory EmptyState.searchEmpty() =>
      EmptyState(icon: Icons.search_off, message: '未找到匹配结果');

  factory EmptyState.loading() =>
      EmptyState(icon: Icons.hourglass_empty, message: '加载中...');

  factory EmptyState.syncSuccess() =>
      EmptyState(icon: Icons.cloud_done, message: '已全部同步', color: Colors.green);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = color ?? c.textTertiary;
    final textColor = color ?? c.textPrimary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: AppSpacing.lg),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(color: textColor),
              ),
              if (hint != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final Color? color;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.color,
  });

  factory EmptyStateCard.noPending() => EmptyStateCard(
    icon: Icons.check_circle_outline,
    message: '暂无待审核提交',
    color: Colors.green,
  );

  factory EmptyStateCard.noReviewed() =>
      EmptyStateCard(icon: Icons.history, message: '暂无已审核记录');

  factory EmptyStateCard.noAbnormal() => EmptyStateCard(
    icon: Icons.check_circle,
    message: '全部到齐，无异常记录',
    color: Colors.green,
  );

  factory EmptyStateCard.noSubmission() =>
      EmptyStateCard(icon: Icons.send_outlined, message: '暂无提交记录');

  factory EmptyStateCard.noTask() => EmptyStateCard(
    icon: Icons.assignment_outlined,
    message: '暂无可提交的任务',
    hint: '请先完成本周记名任务',
  );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: EmptyState(
        icon: icon,
        message: message,
        hint: hint,
        color: color,
      ),
    );
  }
}
