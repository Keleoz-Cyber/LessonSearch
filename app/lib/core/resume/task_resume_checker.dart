import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../shared/providers.dart';

/// 启动时检查未完成的记名任务（executing 阶段），提示用户继续或放弃
class TaskResumeChecker {
  static Future<void> check(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final tasks = await repo.getInProgressTasks();

    // 只恢复记名任务 + executing 阶段
    final resumable = tasks.where((t) =>
        t.type == TaskType.nameCheck &&
        t.phase == TaskPhase.executing).toList();

    if (resumable.isEmpty || !context.mounted) return;

    final task = resumable.first;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('发现未完成任务'),
        content: const Text('上次的记名任务尚未完成，是否继续？'),
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
      // 获取班级名称
      final studentRepo = ref.read(studentRepositoryProvider);
      final allClasses = await studentRepo.getClasses();
      final classNames = task.classIds
          .map((id) {
            final cls = allClasses.where((c) => c.id == id);
            return cls.isNotEmpty ? cls.first.displayName : '未知班级';
          })
          .toList();

      if (!context.mounted) return;
      context.push(
        '/name-check/execute',
        extra: {
          'classIds': task.classIds,
          'classNames': classNames,
          'gradeId': task.selectedGradeId ?? 0,
          'majorId': task.selectedMajorId ?? 0,
          'resumeTaskId': task.id, // 标记为恢复模式
        },
      );
    }
  }
}
