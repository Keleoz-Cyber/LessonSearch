import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers.dart';

class RollCallPage extends ConsumerStatefulWidget {
  final int classId;
  final int gradeId;
  final int majorId;
  final String className;

  const RollCallPage({
    super.key,
    required this.classId,
    required this.gradeId,
    required this.majorId,
    required this.className,
  });

  @override
  ConsumerState<RollCallPage> createState() => _RollCallPageState();
}

class _RollCallPageState extends ConsumerState<RollCallPage> {
  @override
  void initState() {
    super.initState();
    // 启动后初始化点名
    Future.microtask(() {
      ref.read(rollCallProvider.notifier).startRollCall(
            classId: widget.classId,
            gradeId: widget.gradeId,
            majorId: widget.majorId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rollCallProvider);

    // 加载中
    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 错误
    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    // 完成
    if (state.isFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名完成')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                '点名完成',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.className} · 已点名 ${state.processedCount} / ${state.totalCount} 人',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
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

    // 正在点名
    final student = state.currentStudent;
    if (student == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showExitDialog(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${state.processedCount + 1} / ${state.totalCount}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // 学生姓名
            Text(
              student.name,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // 拼音
            Text(
              student.pinyin ?? '',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[500],
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 24),

            // 学号
            Text(
              student.studentNo,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[400],
                    fontFamily: 'monospace',
                  ),
            ),

            const Spacer(flex: 3),

            // 操作按钮
            Row(
              children: [
                // 结束查课
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showFinishDialog(),
                    icon: const Icon(Icons.stop),
                    label: const Text('结束查课'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 下一位
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () =>
                        ref.read(rollCallProvider.notifier).nextStudent(),
                    icon: const Icon(Icons.navigate_next),
                    label: Text(state.hasNext ? '下一位' : '最后一位'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出点名'),
        content: const Text('当前点名进度将保存，是否退出？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.pop();
    }
  }

  Future<void> _showFinishDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束查课'),
        content: Text('已点名 ${ref.read(rollCallProvider).processedCount} / ${ref.read(rollCallProvider).totalCount} 人，确认结束？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认结束')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(rollCallProvider.notifier).finishRollCall();
    }
  }
}
