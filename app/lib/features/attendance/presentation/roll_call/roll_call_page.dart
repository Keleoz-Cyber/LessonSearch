import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/toast.dart';

class RollCallPage extends ConsumerStatefulWidget {
  final List<int> classIds;
  final List<String> classNames;
  final int gradeId;
  final int majorId;
  final String? resumeTaskId;

  const RollCallPage({
    super.key,
    required this.classIds,
    required this.classNames,
    required this.gradeId,
    required this.majorId,
    this.resumeTaskId,
  });

  @override
  ConsumerState<RollCallPage> createState() => _RollCallPageState();
}

class _RollCallPageState extends ConsumerState<RollCallPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authService = ref.read(authServiceProvider);
      if (widget.resumeTaskId != null) {
        ref.read(rollCallProvider.notifier).resumeTask(widget.resumeTaskId!);
      } else {
        ref
            .read(rollCallProvider.notifier)
            .startRollCall(
              classIds: widget.classIds,
              gradeId: widget.gradeId,
              majorId: widget.majorId,
              userId: authService.userId,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rollCallProvider);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名')),
        body: const LoadingOverlay(
          isLoading: true,
          message: '准备中...',
          child: SizedBox.expand(),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('返回'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        final authService = ref.read(authServiceProvider);
                        if (widget.resumeTaskId != null) {
                          ref
                              .read(rollCallProvider.notifier)
                              .resumeTask(widget.resumeTaskId!);
                        } else {
                          ref
                              .read(rollCallProvider.notifier)
                              .startRollCall(
                                classIds: widget.classIds,
                                gradeId: widget.gradeId,
                                majorId: widget.majorId,
                                userId: authService.userId,
                              );
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.isFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名完成')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text('点名完成', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '已点名 ${state.processedCount} / ${state.totalCount} 人',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }

    final student = state.currentStudent;
    if (student == null) return const SizedBox();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.currentClassName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitDialog(),
          ),
          actions: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text(
                  '${state.processedCount + 1} / ${state.totalCount}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Spacer(flex: 2),

                // 学生姓名
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    student.name,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // 拼音
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    student.pinyin ?? '',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[500],
                      letterSpacing: 2,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // 班级 + 学号
                Text(
                  '${state.currentClassName} · ${student.studentNo}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[400],
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),

                Spacer(flex: 3),

                // 操作按钮
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFinishDialog(),
                        icon: Icon(Icons.stop),
                        label: Text('结束查课'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(52),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          ref.read(feedbackServiceProvider).feedback();
                          ref.read(rollCallProvider.notifier).nextStudent();
                        },
                        icon: Icon(Icons.navigate_next),
                        label: Text(state.hasNext ? '下一位' : '最后一位'),
                        style: FilledButton.styleFrom(
                          minimumSize: Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出点名'),
        content: const Text('当前点名尚未完成，请选择操作：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('继续点名'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'abandon'),
            child: const Text('放弃', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('保存退出'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (result) {
      case 'save':
        try {
          await ref.read(rollCallProvider.notifier).saveProgress();
        } catch (e) {
          if (mounted) {
            Toast.show(context, '保存失败: $e');
          }
        }
        if (mounted) context.pop();
      case 'abandon':
        await ref.read(rollCallProvider.notifier).abandonTask();
        if (mounted) context.pop();
      default:
        break;
    }
  }

  Future<void> _showFinishDialog() async {
    final state = ref.read(rollCallProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束查课'),
        content: Text(
          '已点名 ${state.processedCount} / ${state.totalCount} 人，确认结束？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(rollCallProvider.notifier).finishRollCall();
      } catch (e) {
        if (mounted) {
          Toast.show(context, '结束失败: $e');
        }
      }
    }
  }
}
