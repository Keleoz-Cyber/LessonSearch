import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../shared/providers.dart';

/// 启动时检查未完成任务，提示用户继续或放弃
class TaskResumeChecker {
  static Future<void> check(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final tasks = await repo.getInProgressTasks();

    if (tasks.isEmpty || !context.mounted) return;

    final task = tasks.first;
    final typeLabel = task.type == TaskType.rollCall ? '点名' : '记名';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('发现未完成任务'),
        content: Text('上次的$typeLabel任务尚未完成，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'abandon'),
            child: const Text('放弃', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'resume'),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result == 'abandon') {
      await repo.updateTaskStatus(task, status: TaskStatus.abandoned);
    } else if (result == 'resume') {
      // 简化版恢复：导航到选择页让用户重新选择
      // 完整版应恢复到精确的执行页面和位置
      final route = task.type == TaskType.rollCall
          ? '/roll-call/select'
          : '/name-check/select';
      context.push(route);
    }
  }
}
