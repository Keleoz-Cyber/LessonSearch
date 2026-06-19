import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/app_card.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/design_system/widgets/status_pill.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/toast.dart';
import '../../application/roll_call_notifier.dart';

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
    final c = context.colors;
    final state = ref.watch(rollCallProvider);

    if (state.isLoading) {
      return Scaffold(
        backgroundColor: c.bgCanvas,
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
        backgroundColor: c.bgCanvas,
        appBar: AppBar(title: const Text('点名')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 32, color: c.stateDanger),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  state.error!,
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton.secondary(
                      label: '返回',
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.primary(
                      label: '重试',
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
                      leadingIcon: Icons.refresh,
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
        backgroundColor: c.bgCanvas,
        appBar: AppBar(title: const Text('点名完成')),
        body: Center(
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
                    Icons.check_circle,
                    size: 36,
                    color: c.stateSuccess,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '点名完成',
                  style: AppTextStyles.h1.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '已点名 ${state.processedCount} / ${state.totalCount} 人',
                  style: AppTextStyles.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl2),
                AppButton.gradient(
                  label: '返回首页',
                  onPressed: () => context.go('/'),
                  size: AppButtonSize.lg,
                ),
              ],
            ),
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
        backgroundColor: c.bgCanvas,
        appBar: AppBar(
          title: Text(state.currentClassName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitDialog(),
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Text(
                  '${state.processedCount + 1} / ${state.totalCount}',
                  style: AppTextStyles.withTabular(
                    AppTextStyles.bodyMedium,
                  ).copyWith(color: c.textSecondary),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              children: [
                _buildPreviewArea(context, state),
                const Spacer(flex: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    student.name,
                    style: AppTextStyles.display.copyWith(
                      color: c.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    student.pinyin ?? '',
                    style: AppTextStyles.h2.copyWith(
                      color: c.textTertiary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${state.currentClassName} · ${student.studentNo}',
                  style: AppTextStyles.withTabular(
                    AppTextStyles.sm,
                  ).copyWith(color: c.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          primary: AppButton.gradient(
            label: state.hasNext ? '下一位' : '完成',
            onPressed: () {
              ref.read(feedbackServiceProvider).feedback();
              ref.read(rollCallProvider.notifier).nextStudent();
            },
            trailingIcon: state.hasNext ? Icons.navigate_next : Icons.check,
            size: AppButtonSize.lg,
            fullWidth: true,
          ),
          secondary: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 48,
                child: OutlinedButton(
                  onPressed: state.hasPrev
                      ? () {
                          ref.read(feedbackServiceProvider).feedback();
                          ref.read(rollCallProvider.notifier).prevStudent();
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: c.textSecondary,
                    side: BorderSide(color: c.borderDefault),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.normal),
                    ),
                  ),
                  child: const Icon(Icons.navigate_before, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              SizedBox(
                width: 56,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _showFinishDialog(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: c.stateDanger,
                    side: BorderSide(
                      color: c.stateDanger.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.normal),
                    ),
                  ),
                  child: Text(
                    '结束',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: c.stateDanger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea(BuildContext context, RollCallState state) {
    final c = context.colors;
    final prevThree = state.prevThreeStudents;
    final nextOne = state.nextStudent;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill.success(label: '已点'),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: prevThree.isEmpty
                    ? Text(
                        '暂无',
                        style: AppTextStyles.sm.copyWith(
                          color: c.textTertiary,
                        ),
                      )
                    : Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: prevThree
                            .map(
                              (s) => Text(
                                s.name,
                                style: AppTextStyles.sm.copyWith(
                                  color: c.stateSuccess,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: c.borderSubtle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const StatusPill.info(label: '下一位'),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: nextOne == null
                    ? Text(
                        '已是最后',
                        style: AppTextStyles.sm.copyWith(
                          color: c.textTertiary,
                        ),
                      )
                    : Text(
                        nextOne.name,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showExitDialog() async {
    final c = context.colors;
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
            style: TextButton.styleFrom(foregroundColor: c.stateDanger),
            child: const Text('放弃'),
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
