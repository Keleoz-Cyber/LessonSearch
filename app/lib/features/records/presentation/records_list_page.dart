import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('查课记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const Center(child: Text('暂无查课记录'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _summaries.length,
                    itemBuilder: (context, index) {
                      final s = _summaries[index];
                      return _TaskCard(
                        summary: s,
                        onTap: () async {
                          await context.push('/records/${s.id}');
                          _load(); // 返回时刷新
                        },
                        onDelete: () => _confirmDelete(s),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _confirmDelete(TaskSummary summary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确认删除 ${summary.classNames.join("、")} 的${summary.typeLabel}记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final repo = ref.read(recordsRepositoryProvider);
      await repo.deleteTask(summary.id);
      _load();
    }
  }
}

class _TaskCard extends StatelessWidget {
  final TaskSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = summary.createdAt.toString().substring(0, 16);
    final isAbandoned = summary.status == TaskStatus.abandoned;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: summary.type == TaskType.rollCall
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      summary.typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: summary.type == TaskType.rollCall ? Colors.blue : Colors.green,
                      ),
                    ),
                  ),
                  if (isAbandoned) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('已放弃', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.classNames.join('、'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '共${summary.totalStudents}人 · '
                '${summary.type == TaskType.rollCall
                    ? "已点${summary.presentCount + summary.lateCount} 未点${summary.absentCount + summary.leaveCount + summary.otherCount}"
                    : "到${summary.presentCount} 缺${summary.absentCount} 迟${summary.lateCount} 假${summary.leaveCount} 他${summary.otherCount}"}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
