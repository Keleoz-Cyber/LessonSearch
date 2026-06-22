import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

/// SyncQueue 详情数据模型
class SyncIssueGroup {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<SyncQueueData> items;
  final String actionHint;

  SyncIssueGroup({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.items,
    required this.actionHint,
  });
}

/// 将 SyncQueue 数据分组为 SyncIssueGroup
List<SyncIssueGroup> _buildSyncIssueGroups(List<SyncQueueData> allItems) {
  final pending = allItems.where((s) => s.syncStatus == 'pending').toList();
  final authFailed = allItems.where((s) =>
      s.syncStatus == 'failed' && s.retryCount == 999).toList();
  final retrying = allItems.where((s) =>
      s.syncStatus == 'failed' && s.retryCount > 0 && s.retryCount < 5).toList();
  final givenUp = allItems.where((s) =>
      s.syncStatus == 'failed' && s.retryCount >= 5 && s.retryCount < 999).toList();

  return [
    if (pending.isNotEmpty)
      SyncIssueGroup(
        title: '待同步',
        description: '这些修改正在等待同步到服务器，通常会在后台自动完成。',
        icon: Icons.sync,
        color: Colors.blue,
        items: pending,
        actionHint: '系统会自动同步，无需操作',
      ),
    if (authFailed.isNotEmpty)
      SyncIssueGroup(
        title: '登录状态已过期',
        description: '由于登录凭证过期，这些修改无法同步。重新登录后会自动恢复同步。',
        icon: Icons.lock_clock,
        color: Colors.orange,
        items: authFailed,
        actionHint: '请重新登录后继续同步',
      ),
    if (retrying.isNotEmpty)
      SyncIssueGroup(
        title: '同步失败（将自动重试）',
        description: '网络不稳定或服务器暂时不可用，系统会自动重试（最多5次）。',
        icon: Icons.wifi_off,
        color: Colors.amber,
        items: retrying,
        actionHint: '检查网络后点击"立即重试"',
      ),
    if (givenUp.isNotEmpty)
      SyncIssueGroup(
        title: '同步失败（已放弃）',
        description: '已尝试5次仍未成功，可能是服务器错误或数据问题。建议检查网络后手动重试。',
        icon: Icons.error_outline,
        color: Colors.red,
        items: givenUp,
        actionHint: '点击"立即重试"可重置并再次尝试',
      ),
  ];
}

/// 查询所有未同步/失败项（StreamProvider，每1秒自动刷新）
final syncIssuesProvider = StreamProvider<List<SyncIssueGroup>>((ref) async* {
  final db = ref.watch(databaseProvider);

  // 初始查询
  final initialItems = await db.select(db.syncQueue).get();
  yield _buildSyncIssueGroups(initialItems);

  // 每1秒轮询一次，实时刷新
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    final items = await db.select(db.syncQueue).get();
    yield _buildSyncIssueGroups(items);
  }
});

class SyncIssuesPage extends ConsumerWidget {
  const SyncIssuesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final issuesAsync = ref.watch(syncIssuesProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('同步问题详情')),
      body: issuesAsync.when(
        loading: () => Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(c.brandPrimary),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              '加载失败: $e',
              style: AppTextStyles.body.copyWith(color: c.stateDanger),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildIssueList(context, ref, groups);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.stateSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 36,
                color: c.stateSuccess,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '所有数据已同步',
              style: AppTextStyles.h2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '本地数据与服务器保持一致',
              style: AppTextStyles.sm.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueList(
    BuildContext context,
    WidgetRef ref,
    List<SyncIssueGroup> groups,
  ) {
    final c = context.colors;
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // 顶部统计卡片
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: c.stateWarning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '共有 $totalItems 条数据未同步',
                      style: AppTextStyles.h3.copyWith(color: c.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: groups
                    .map(
                      (g) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: g.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${g.title}: ${g.items.length}',
                          style: AppTextStyles.xs.copyWith(color: g.color),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 立即重试按钮
        AppButton.primary(
          label: '立即重试同步',
          onPressed: () => _retrySync(context, ref, groups),
          leadingIcon: Icons.sync,
          size: AppButtonSize.lg,
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            _buildRetryHint(groups),
            style: AppTextStyles.sm.copyWith(color: c.textTertiary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 分类详情
        ...groups.expand(
          (group) => [
            _buildGroupHeader(context, group),
            const SizedBox(height: AppSpacing.sm),
            ...group.items.map(
              (item) => _buildIssueItem(context, ref, item, group.color),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, SyncIssueGroup group) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: group.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: group.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, color: group.color, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  group.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: group.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${group.items.length} 条',
                style: AppTextStyles.sm.copyWith(color: group.color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            group.description,
            style: AppTextStyles.sm.copyWith(
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: group.color.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  group.actionHint,
                  style: AppTextStyles.sm.copyWith(
                    color: group.color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueItem(BuildContext context, WidgetRef ref, SyncQueueData item, Color color) {
    final c = context.colors;
    final entityTypeLabel = _getEntityTypeLabel(item.entityType);
    final actionLabel = item.action == 'create' ? '创建' : item.action == 'update' ? '更新' : '删除';
    final createdAt = DateFormat('MM-dd HH:mm').format(item.createdAt);
    final retryInfo = item.retryCount > 0 && item.retryCount < 999
        ? '已重试 ${item.retryCount} 次'
        : item.retryCount >= 999
            ? '不可重试'
            : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      child: Dismissible(
        key: ValueKey('sync-item-${item.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('跳过此项'),
              content: Text('确定跳过这条同步项？\n\n$entityTypeLabel$actionLabel · ID: ${item.entityId}\n\n跳过后此项不再同步，本地数据保留。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.stateWarning,
                    foregroundColor: c.onBrand,
                  ),
                  child: const Text('跳过'),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) async {
          final db = ref.read(databaseProvider);
          await (db.update(db.syncQueue)..where((s) => s.id.equals(item.id))).write(
            const SyncQueueCompanion(
              syncStatus: drift.Value('synced'),
              syncedAt: drift.Value(null),
            ),
          );
          ref.invalidate(syncIssuesProvider);
          if (context.mounted) {
            Toast.show(context, '已跳过');
          }
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: c.stateWarning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.skip_next, color: c.stateWarning),
        ),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$entityTypeLabel$actionLabel',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${item.entityId}',
                      style: AppTextStyles.withTabular(
                        AppTextStyles.xs,
                      ).copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    createdAt,
                    style: AppTextStyles.withTabular(
                      AppTextStyles.xs,
                    ).copyWith(color: c.textTertiary),
                  ),
                  if (retryInfo.isNotEmpty)
                    Text(
                      retryInfo,
                      style: AppTextStyles.xs.copyWith(
                        color: color.withValues(alpha: 0.85),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.swipe_left,
                    size: 14,
                    color: c.textTertiary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEntityTypeLabel(String entityType) {
    switch (entityType) {
      case 'task':
        return '任务';
      case 'record':
        return '考勤记录';
      default:
        return entityType;
    }
  }

  String _buildRetryHint(List<SyncIssueGroup> groups) {
    final hasAuthFailed = groups.any((g) => g.title == '登录状态已过期');
    final hasGivenUp = groups.any((g) => g.title == '同步失败（已放弃）');
    
    if (hasAuthFailed && hasGivenUp) {
      return '会先重置已放弃项，登录过期项需重新登录后同步';
    } else if (hasAuthFailed) {
      return '请先重新登录后再同步登录过期项';
    } else if (hasGivenUp) {
      return '会先重置已放弃项，然后重新尝试同步';
    }
    return '旧版本遗留的无效项会自动跳过，不影响已提交数据';
  }

  Future<void> _retrySync(
    BuildContext context,
    WidgetRef ref,
    List<SyncIssueGroup> groups,
  ) async {
    final hasAuthFailed = groups.any((g) => g.title == '登录状态已过期');
    final hasGivenUp = groups.any((g) => g.title == '同步失败（已放弃）');

    try {
      // Step 1: 如果有登录过期项，提示用户
      if (hasAuthFailed && context.mounted) {
        Toast.show(
          context,
          '检测到登录过期项目，请先重新登录后再同步这些项目',
        );
      }

      // Step 2: 重置已放弃项（retryCount>=5 且 <999）
      if (hasGivenUp) {
        final localDS = ref.read(attendanceLocalDSProvider);
        final count = await localDS.resetGivenUpSyncItems();
        if (count > 0 && context.mounted) {
          Toast.show(context, '已重置 $count 项失败记录，准备重新同步');
        }
      }

      // Step 3: 执行同步
      if (context.mounted) {
        Toast.show(context, '开始同步...');
      }
      final result = await ref.read(syncServiceProvider).syncNow();

      if (context.mounted) {
        if (result.failed == 0 && !hasAuthFailed) {
          Toast.show(context, '同步完成，所有数据已同步');
        } else if (result.failed == 0 && hasAuthFailed) {
          Toast.show(
            context,
            '同步完成，登录过期项目仍需重新登录后同步',
          );
        } else {
          Toast.show(context, '同步完成，${result.failed} 项失败');
        }
        // 刷新页面
        ref.invalidate(syncIssuesProvider);
      }
    } catch (e) {
      if (context.mounted) {
        Toast.show(context, '同步失败: $e');
      }
    }
  }
}
