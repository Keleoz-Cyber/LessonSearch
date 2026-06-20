import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';

class SyncTab extends ConsumerStatefulWidget {
  const SyncTab({super.key});

  @override
  ConsumerState<SyncTab> createState() => _SyncTabState();
}

class _SyncTabState extends ConsumerState<SyncTab> {
  List<SyncQueueData> _pending = [];
  List<SyncQueueData> _failed = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      final pending = await local.getPendingSyncItems();
      final failed = await local.getFailedSyncItems();
      if (!mounted) return;
      setState(() {
        _pending = pending;
        _failed = failed;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final sync = ref.read(syncServiceProvider);
      final result = await sync.processQueueWithStats();
      if (mounted) {
        Toast.show(
          context,
          '成功${result.success} 失败${result.failed} 跳过${result.skipped}',
        );
      }
    } catch (e) {
      if (mounted) Toast.show(context, '同步失败: $e');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        await _load();
      }
    }
  }

  Future<void> _retryFailed() async {
    try {
      final local = ref.read(attendanceLocalDSProvider);
      await local.retryAllFailed();
      if (mounted) {
        Toast.show(context, '已重置失败记录');
        await _load();
      }
    } catch (e) {
      if (mounted) Toast.show(context, '重试失败: $e');
    }
  }

  Future<void> _clearQueue() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定清空同步队列？不会删除本地任务数据。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final local = ref.read(attendanceLocalDSProvider);
      await local.clearSyncQueue();
      if (mounted) {
        Toast.show(context, '已清空');
        await _load();
      }
    } catch (e) {
      if (mounted) Toast.show(context, '清空失败: $e');
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      final db = ref.read(databaseProvider);
      await (db.delete(db.syncQueue)..where((t) => t.id.equals(id))).go();
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _syncing ? null : _syncNow,
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 18),
                label: const Text('立即同步'),
              ),
              if (_failed.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _retryFailed,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('重试(${_failed.length})'),
                  style: OutlinedButton.styleFrom(foregroundColor: c.stateDanger),
                ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
              ),
            ],
          ),
        ),
        Expanded(
          child: _pending.isEmpty && _failed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: c.textTertiary),
                      const SizedBox(height: AppSpacing.sm),
                      Text('同步队列为空',
                          style: AppTextStyles.sm.copyWith(color: c.textTertiary)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (_pending.isNotEmpty) ...[
                      _subHeader(
                          '待同步 (${_pending.length})', Icons.cloud_upload, c.stateWarning),
                      const SizedBox(height: AppSpacing.xs),
                      ..._pending.map((item) => _SyncItemTile(
                            item: item,
                            highlightColor: c.stateWarning,
                            onDelete: () => _deleteItem(item.id),
                          )),
                    ],
                    if (_failed.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _subHeader(
                          '失败 (${_failed.length})', Icons.error_outline, c.stateDanger),
                      const SizedBox(height: AppSpacing.xs),
                      ..._failed.map((item) => _SyncItemTile(
                            item: item,
                            highlightColor: c.stateDanger,
                            onDelete: () => _deleteItem(item.id),
                          )),
                    ],
                  ],
                ),
        ),
        Divider(height: 1, color: c.borderSubtle),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearQueue,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空同步队列'),
              style: OutlinedButton.styleFrom(foregroundColor: c.stateDanger),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _subHeader(String title, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: AppSpacing.xs + 2),
      Text(title,
          style: AppTextStyles.sm.copyWith(
              fontWeight: FontWeight.w600, color: color)),
    ],
  );
}

class _SyncItemTile extends StatelessWidget {
  final SyncQueueData item;
  final Color highlightColor;
  final VoidCallback onDelete;

  const _SyncItemTile({
    required this.item,
    required this.highlightColor,
    required this.onDelete,
  });

  String _formatPayload(String? payload) {
    if (payload == null) return '-';
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map.length <= 4) {
        return map.entries.map((e) => '${e.key}=${e.value}').join(', ');
      }
      return '${map.keys.take(4).join(", ")}...';
    } catch (_) {
      if (payload.length > 60) return '${payload.substring(0, 60)}...';
      return payload;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: highlightColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          item.action.toUpperCase(),
                          style: AppTextStyles.xs.copyWith(
                              fontWeight: FontWeight.w600, color: highlightColor),
                        ),
                      ),
                      Text(item.entityType,
                          style: AppTextStyles.sm.copyWith(
                              fontWeight: FontWeight.w500, color: c.textPrimary)),
                      Text('#${item.entityId}',
                          style: AppTextStyles.xs.copyWith(color: c.textTertiary)),
                      if (item.retryCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs + 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.stateDanger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text('x${item.retryCount}',
                              style: AppTextStyles.xs.copyWith(color: c.stateDanger)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPayload(item.payload),
                    style: AppTextStyles.xs.copyWith(
                        fontFamily: 'monospace', color: c.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: c.textTertiary),
              onPressed: onDelete,
              tooltip: '删除',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
