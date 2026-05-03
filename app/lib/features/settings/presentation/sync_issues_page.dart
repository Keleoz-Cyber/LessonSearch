import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
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
    final issuesAsync = ref.watch(syncIssuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('同步问题详情')),
      body: issuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '所有数据已同步',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '本地数据与服务器保持一致',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueList(
    BuildContext context,
    WidgetRef ref,
    List<SyncIssueGroup> groups,
  ) {
    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 顶部统计卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共有 $totalItems 条数据未同步',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: groups.map((g) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: g.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${g.title}: ${g.items.length}',
                        style: TextStyle(
                          color: g.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 立即重试按钮
        FilledButton.icon(
          onPressed: () => _retrySync(context, ref, groups),
          icon: const Icon(Icons.sync),
          label: const Text('立即重试同步'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _buildRetryHint(groups),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 分类详情
        ...groups.expand((group) => [
          _buildGroupHeader(context, group),
          const SizedBox(height: 8),
          ...group.items.map((item) => _buildIssueItem(context, item, group.color)),
          const SizedBox(height: 24),
        ]),
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, SyncIssueGroup group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: group.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: group.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, color: group.color, size: 20),
              const SizedBox(width: 8),
              Text(
                group.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: group.color,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${group.items.length} 条',
                style: TextStyle(
                  color: group.color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            group.description,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: group.color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.actionHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: group.color.withValues(alpha: 0.8),
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

  Widget _buildIssueItem(BuildContext context, SyncQueueData item, Color color) {
    final entityTypeLabel = _getEntityTypeLabel(item.entityType);
    final actionLabel = item.action == 'create' ? '创建' : '更新';
    final createdAt = DateFormat('MM-dd HH:mm').format(item.createdAt);
    final retryInfo = item.retryCount > 0 && item.retryCount < 999
        ? ' (已重试 ${item.retryCount} 次)'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$entityTypeLabel$actionLabel',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${item.entityId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  createdAt,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (retryInfo.isNotEmpty)
                  Text(
                    retryInfo,
                    style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ],
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
    return '点击后会立即尝试同步所有待同步和失败的数据';
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
