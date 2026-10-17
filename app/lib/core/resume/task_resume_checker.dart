import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../shared/providers.dart';

/// 启动时检查未完成的记名任务（executing/confirming/text_generating 阶段），提示用户继续或放弃
class TaskResumeChecker {
  static Future<void> check(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(attendanceRepositoryProvider);

    // 未登录时不恢复任务
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) return;

    final currentUserId = ref.read(authServiceProvider).userId;
    final tasks = await repo.getResumableTasks();

    // 恢复记名任务 + executing/confirming/text_generating 阶段 + 属于当前用户
    final resumable = tasks
        .where(
          (t) =>
              (t.phase == TaskPhase.executing ||
                  t.phase == TaskPhase.confirming ||
                  t.phase == TaskPhase.textGenerating) &&
              t.userId == currentUserId,
        )
        .toList();

    if (resumable.isEmpty || !context.mounted) return;

    final task = resumable.first;

    final phaseLabel = switch (task.phase) {
      TaskPhase.confirming => '已到确认页',
      TaskPhase.textGenerating => '已到文案生成页',
      _ => '',
    };

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('发现未完成任务'),
        content: Text(
          phaseLabel.isEmpty
              ? '上次的${task.type == TaskType.rollCall ? '点名' : '记名'}任务尚未完成，是否继续？'
              : '上次的记名任务$phaseLabel，尚未完成。是否继续？',
        ),
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
      if (task.type == TaskType.nameCheck) {
        await ref.read(nameCheckProvider.notifier).resumeTask(task.id);
        if (!context.mounted) return;
        final restored = ref.read(nameCheckProvider);
        if (restored.task == null || restored.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(restored.error ?? '恢复任务失败，请稍后重试')),
          );
          return;
        }
      }
      // 获取班级名称
      final studentRepo = ref.read(studentRepositoryProvider);
      final allClasses = await studentRepo.getClasses();
      final classNames = task.classIds.map((id) {
        final cls = allClasses.where((c) => c.id == id);
        return cls.isNotEmpty ? cls.first.displayName : '未知班级';
      }).toList();

      if (!context.mounted) return;

      final extra = {
        'classIds': task.classIds,
        'classNames': classNames,
        'gradeId': task.selectedGradeId ?? 0,
        'majorId': task.selectedMajorId ?? 0,
        'resumeTaskId': task.id,
        'taskId': task.id,
      };

      // 根据 phase 跳不同页面
      if (task.type == TaskType.rollCall) {
        context.push('/roll-call/execute', extra: extra);
        return;
      }
      switch (task.phase) {
        case TaskPhase.confirming:
          context.push('/confirmation', extra: extra);
        case TaskPhase.textGenerating:
          context.push('/text-gen', extra: extra);
        default:
          context.push('/name-check/execute', extra: extra);
      }
    }
  }
}
