import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/notification/notification_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/status_pill.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../domain/duty_plan.dart';

class DutyPlanListPage extends ConsumerWidget {
  const DutyPlanListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final plansAsync = ref.watch(dutyPlansProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('查课计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '通知权限',
            onPressed: () => _checkPermission(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/duty-plan/create');
          ref.invalidate(dutyPlansProvider);
          ref.invalidate(upcomingDutyPlansProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('新建'),
        backgroundColor: c.brandPrimary,
        foregroundColor: c.onBrand,
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '加载失败: $e',
            style: AppTextStyles.sm.copyWith(color: c.stateDanger),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note_outlined,
                      size: 48, color: c.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '还没有查课计划',
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '点击右下角“新建”创建你的第一个计划',
                    style:
                        AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            );
          }
          return _buildList(context, ref, plans);
        },
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<DutyPlan> plans) {
    final byWeek = <int, List<DutyPlan>>{};
    for (final p in plans) {
      byWeek.putIfAbsent(p.weekNumber, () => []).add(p);
    }
    final weekNumbers = byWeek.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl3,
      ),
      itemCount: weekNumbers.length,
      itemBuilder: (context, idx) {
        final w = weekNumbers[idx];
        final wPlans = byWeek[w]!;
        return _WeekSection(weekNumber: w, plans: wPlans);
      },
    );
  }

  Future<void> _checkPermission(BuildContext context) async {
    final svc = NotificationService();
    final granted = await svc.isPermissionGranted();
    if (!context.mounted) return;
    if (granted) {
      Toast.show(context, '通知权限已开启');
    } else {
      final ok = await svc.requestPermission();
      if (!context.mounted) return;
      Toast.show(context, ok ? '通知权限已开启' : '通知权限未开启，请到系统设置中允许');
    }
  }
}

class _WeekSection extends ConsumerWidget {
  final int weekNumber;
  final List<DutyPlan> plans;

  const _WeekSection({required this.weekNumber, required this.plans});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final byWeekday = <int, List<DutyPlan>>{};
    for (final p in plans) {
      byWeekday.putIfAbsent(p.weekday, () => []).add(p);
    }
    final weekdays = byWeekday.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.brandPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '第 $weekNumber 周',
                  style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${plans.length} 节',
                  style: AppTextStyles.sm.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
          ...weekdays.expand((wd) {
            final wdPlans = byWeekday[wd]!
              ..sort((a, b) => a.period.compareTo(b.period));
            return wdPlans.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DutyPlanCard(plan: p),
                ));
          }),
        ],
      ),
    );
  }
}

class _DutyPlanCard extends ConsumerWidget {
  final DutyPlan plan;
  const _DutyPlanCard({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isPast = plan.isPast;
    final color = isPast ? c.textTertiary : c.brandPrimary;
    final fmt = DateFormat('MM月dd日');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _showActions(context, ref),
      child: Row(
        children: [
          Container(
            width: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                Text(
                  plan.weekdayLabel,
                  style: AppTextStyles.xs
                      .copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '第${plan.period}节',
                  style: AppTextStyles.sm
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.className ?? '${plan.classIds.length} 个班级',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPast)
                      const StatusPill.neutral(label: '已结束')
                    else if (!plan.reminderEnabled)
                      const StatusPill.neutral(label: '提醒已关')
                    else
                      const StatusPill.success(label: '已设提醒'),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(plan.classStartAt)} · ${plan.timeRange}${plan.classroom != null ? ' · ${plan.classroom}' : ''}',
                  style: AppTextStyles.withTabular(AppTextStyles.xs)
                      .copyWith(color: c.textTertiary),
                ),
                if (plan.remark != null && plan.remark!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plan.remark!,
                    style: AppTextStyles.xs.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                plan.reminderEnabled
                    ? Icons.notifications_off
                    : Icons.notifications_active,
                color: c.brandPrimary,
              ),
              title: Text(plan.reminderEnabled ? '关闭提醒' : '开启提醒'),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.stateDanger),
              title: Text('删除', style: TextStyle(color: c.stateDanger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    final repo = ref.read(dutyPlanRepositoryProvider);
    final notif = NotificationService();

    if (action == 'toggle') {
      final newEnabled = !plan.reminderEnabled;
      if (newEnabled) {
        final classroomStr =
            plan.classroom != null ? ' @ ${plan.classroom}' : '';
        await notif.scheduleDutyReminder(
          notificationId: plan.notificationId,
          title: '查课提醒 · 第${plan.period}节$classroomStr',
          body: '${plan.weekdayLabel} ${plan.timeRange}$classroomStr 即将开始，记得查课',
          scheduledAt: plan.remindAt,
          payload: plan.id,
        );
      } else {
        await notif.cancel(plan.notificationId);
      }
      await repo.upsert(DutyPlan(
        id: plan.id,
        weekNumber: plan.weekNumber,
        weekday: plan.weekday,
        period: plan.period,
        classIds: plan.classIds,
        className: plan.className,
        classroom: plan.classroom,
        remark: plan.remark,
        notificationId: plan.notificationId,
        reminderEnabled: newEnabled,
        classStartAt: plan.classStartAt,
        createdAt: plan.createdAt,
      ));
    } else if (action == 'delete') {
      await notif.cancel(plan.notificationId);
      await repo.delete(plan.id);
    }

    ref.invalidate(dutyPlansProvider);
    ref.invalidate(upcomingDutyPlansProvider);
    if (context.mounted) {
      Toast.show(context, action == 'delete' ? '已删除' : '提醒已更新');
    }
  }
}