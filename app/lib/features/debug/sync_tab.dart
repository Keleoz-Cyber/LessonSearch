import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

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
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
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
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('同步队列为空',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_pending.isNotEmpty) ...[
                      _subHeader(
                          '待同步 (${_pending.length})', Icons.cloud_upload, Colors.orange),
                      const SizedBox(height: 4),
                      ..._pending.map((item) => _SyncItemTile(
                            item: item,
                            highlightColor: Colors.orange,
                            onDelete: () => _deleteItem(item.id),
                          )),
                    ],
                    if (_failed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _subHeader(
                          '失败 (${_failed.length})', Icons.error_outline, Colors.red),
                      const SizedBox(height: 4),
                      ..._failed.map((item) => _SyncItemTile(
                            item: item,
                            highlightColor: Colors.red,
                            onDelete: () => _deleteItem(item.id),
                          )),
                    ],
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearQueue,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清空同步队列'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color)),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: highlightColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: highlightColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.action.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: highlightColor),
                        ),
                      ),
                      Text(item.entityType,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('#${item.entityId}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      if (item.retryCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('x${item.retryCount}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.red)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPayload(item.payload),
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
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
