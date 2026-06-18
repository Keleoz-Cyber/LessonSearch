import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/design_system/widgets/progress_bar.dart';
import '../../../../shared/design_system/widgets/segmented_control.dart';
import '../../../../shared/design_system/widgets/status_pill.dart';
import '../../../../shared/design_system/widgets/sync_status_banner.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/toast.dart';
import '../../../attendance/application/name_check_notifier.dart';
import '../../../attendance/domain/models.dart';

class NameCheckPage extends ConsumerStatefulWidget {
  final List<int> classIds;
  final List<String> classNames;
  final int gradeId;
  final int majorId;
  final String? resumeTaskId;

  const NameCheckPage({
    super.key,
    required this.classIds,
    required this.classNames,
    required this.gradeId,
    required this.majorId,
    this.resumeTaskId,
  });

  @override
  ConsumerState<NameCheckPage> createState() => _NameCheckPageState();
}

class _NameCheckPageState extends ConsumerState<NameCheckPage> {
  int? _focusedIndex = 0; // 默认选中第一个
  bool _isMarking = false;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildTopBar(BuildContext context, NameCheckState state) {
    final c = context.colors;
    final cls = state.currentClass;
    final segments = _calcProgressSegments(state, c);

    return Container(
      decoration: BoxDecoration(
        color: c.bgCanvas,
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: c.textPrimary),
                    onPressed: () => _showExitDialog(context),
                  ),
                  Expanded(
                    child: Text(
                      cls?.displayName ?? '',
                      style: AppTextStyles.h2.copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${state.processedStudents}/${state.totalStudents}',
                      style: AppTextStyles.withTabular(AppTextStyles.bodyMedium)
                          .copyWith(color: c.textSecondary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: c.brandPrimary,
                    ),
                    tooltip: '确认名单',
                    onPressed: _isMarking
                        ? null
                        : () => _showFinishDialog(context, state),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedProgressBar(
                segments: segments,
                totalCount: state.totalStudents,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ProgressSegment> _calcProgressSegments(
    NameCheckState state,
    AppColors c,
  ) {
    int present = 0, absent = 0, late_ = 0, leave = 0, other = 0;
    for (final list in state.studentsByClass.values) {
      for (final s in list) {
        switch (s.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
          case AttendanceStatus.late_:
            late_++;
            break;
          case AttendanceStatus.leave:
            leave++;
            break;
          case AttendanceStatus.other:
            other++;
            break;
          case AttendanceStatus.pending:
            break;
        }
      }
    }
    return [
      ProgressSegment(value: present, color: c.stateSuccess),
      ProgressSegment(value: absent, color: c.stateDanger),
      ProgressSegment(value: late_, color: c.stateWarning),
      ProgressSegment(value: leave, color: c.stateInfo),
      ProgressSegment(value: other, color: c.textSecondary),
    ];
  }

  Widget _smallActionButton(
    String label,
    Color color,
    VoidCallback? onPressed,
  ) {
    final c = context.colors;
    final disabled = onPressed == null;
    return SizedBox(
      width: 44,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: color,
          side: BorderSide(
            color: disabled ? c.borderSubtle : color.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.normal),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: disabled ? c.textDisabled : color,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authService = ref.read(authServiceProvider);
      if (widget.resumeTaskId != null) {
        ref.read(nameCheckProvider.notifier).resumeTask(widget.resumeTaskId!);
      } else {
        ref
            .read(nameCheckProvider.notifier)
            .startNameCheck(
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
    final state = ref.watch(nameCheckProvider);
    final hasSyncFailed = ref.watch(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.when(
      data: (failed) => failed,
      loading: () => false,
      error: (error, stackTrace) => false,
    );

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('记名')),
        body: const LoadingOverlay(
          isLoading: true,
          message: '加载学生数据...',
          child: SizedBox.expand(),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('记名')),
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
                FilledButton.icon(
                  onPressed: () {
                    final authService = ref.read(authServiceProvider);
                    if (widget.resumeTaskId != null) {
                      ref
                          .read(nameCheckProvider.notifier)
                          .resumeTask(widget.resumeTaskId!);
                    } else {
                      ref
                          .read(nameCheckProvider.notifier)
                          .startNameCheck(
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
          ),
        ),
      );
    }

    if (state.isFinished) {
      return Scaffold(
        appBar: AppBar(title: const Text('记名')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildExecutingView(context, state, isSyncFailed);
  }

  Widget _buildExecutingView(
    BuildContext context,
    NameCheckState state,
    bool isSyncFailed,
  ) {
    final students = state.currentStudents;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitDialog(context);
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(
            72 + MediaQuery.paddingOf(context).top,
          ),
          child: _buildTopBar(context, state),
        ),
        body: Column(
          children: [
            // 班级切换标签
            if (state.classes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppSegmentedControl<int>(
                  items: [
                    for (var i = 0; i < state.classes.length; i++)
                      AppSegmentedItem(
                        value: i,
                        label: state.classes[i].displayName,
                      ),
                  ],
                  value: state.currentClassIndex,
                  onChanged: (i) {
                    ref.read(nameCheckProvider.notifier).switchClass(i);
                    _pageController.animateToPage(
                      i,
                      duration: AppDuration.normal,
                      curve: AppCurves.normal,
                    );
                    setState(() => _focusedIndex = 0);
                  },
                ),
              ),

            // 同步失败红色提示条
            if (isSyncFailed)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SyncStatusBanner(
                  state: SyncBannerState.failed,
                  title: '存在同步失败数据',
                  description: '为避免数据不一致，编辑已锁定。请到同步问题详情处理。',
                ),
              ),

            // 学生列表 - 使用 PageView 支持左右滑动
            Expanded(
              child: state.classes.length > 1
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: state.classes.length,
                      onPageChanged: (index) {
                        ref.read(nameCheckProvider.notifier).switchClass(index);
                        setState(() => _focusedIndex = 0);
                      },
                      itemBuilder: (context, classIndex) {
                        final cls = state.classes[classIndex];
                        final classStudents =
                            state.studentsByClass[cls.id] ?? [];
                        return _ClassStudentGrid(
                          students: classStudents,
                          focusedIndex: classIndex == state.currentClassIndex
                              ? _focusedIndex
                              : null,
                          onTap: (index) {
                            if (classIndex != state.currentClassIndex) {
                              ref
                                  .read(nameCheckProvider.notifier)
                                  .switchClass(classIndex);
                            }
                            setState(() => _focusedIndex = index);
                          },
                        );
                      },
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = 2;
                        final itemWidth =
                            (constraints.maxWidth - 12 * 2 - 8) /
                            crossAxisCount;
                        const itemHeight = 56.0;
                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: itemWidth / itemHeight,
                              ),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final sw = students[index];
                            final isFocused = _focusedIndex == index;

                            return RepaintBoundary(
                              key: ValueKey(sw.student.id),
                              child: _StudentCard(
                                name: sw.student.name,
                                studentNo: sw.student.studentNo,
                                status: sw.status,
                                remark: sw.remark,
                                isFocused: isFocused,
                                onTap: () =>
                                    setState(() => _focusedIndex = index),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            // 底部操作栏
            _buildBottomBar(context, state, students),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    NameCheckState state,
    List<StudentWithStatus> students,
  ) {
    final classId = state.currentClass?.id;
    if (classId == null) return const SizedBox();

    // 检查所有班级是否有pending学生
    final hasPendingInAllClasses = state.classes.any((cls) {
      final classStudents = state.studentsByClass[cls.id] ?? [];
      return classStudents.any((s) => s.status == AttendanceStatus.pending);
    });

    // 跳转到下一个pending学生
    void jumpToNextPending() {
      // 查找当前班级下一个pending
      final nextIndex = students.indexWhere(
        (s) => s.status == AttendanceStatus.pending,
        _focusedIndex! + 1,
      );

      if (nextIndex >= 0) {
        setState(() => _focusedIndex = nextIndex);
        return;
      }

      // 当前班级没有pending，查找其他班级
      if (state.classes.length > 1) {
        for (int i = 0; i < state.classes.length; i++) {
          if (i == state.currentClassIndex) continue;
          final cls = state.classes[i];
          final classStudents = state.studentsByClass[cls.id] ?? [];
          final firstPending = classStudents.indexWhere(
            (s) => s.status == AttendanceStatus.pending,
          );
          if (firstPending >= 0) {
            ref.read(nameCheckProvider.notifier).switchClass(i);
            _pageController.animateToPage(
              i,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
            setState(() => _focusedIndex = firstPending);
            return;
          }
        }
      }

      // 没有找到pending，保持焦点
      setState(() => _focusedIndex = _focusedIndex);
    }

    Future<void> mark(AttendanceStatus status, {String? remark}) async {
      if (_isMarking ||
          _focusedIndex == null ||
          _focusedIndex! >= students.length) {
        return;
      }
      final studentId = students[_focusedIndex!].student.id;
      setState(() => _isMarking = true);
      try {
        ref.read(feedbackServiceProvider).feedback();
        await ref
            .read(nameCheckProvider.notifier)
            .markStudentById(classId, studentId, status, remark: remark);
        if (!mounted) return;

        // 有pending时自动跳转，无pending时焦点不动
        if (hasPendingInAllClasses) {
          jumpToNextPending();
        } else {
          setState(() => _focusedIndex = _focusedIndex);
        }
      } catch (_) {
        if (context.mounted) Toast.show(context, '标记失败，请重试');
      } finally {
        if (mounted) setState(() => _isMarking = false);
      }
    }

    Future<void> markPresent() async {
      if (_isMarking ||
          _focusedIndex == null ||
          _focusedIndex! >= students.length) {
        return;
      }
      final studentId = students[_focusedIndex!].student.id;
      setState(() => _isMarking = true);
      try {
        ref.read(feedbackServiceProvider).feedback();
        await ref
            .read(nameCheckProvider.notifier)
            .markStudentById(classId, studentId, AttendanceStatus.present);
        if (!mounted) return;

        // 有pending时自动跳转，无pending时焦点不动
        if (hasPendingInAllClasses) {
          jumpToNextPending();
        } else {
          setState(() => _focusedIndex = _focusedIndex);
        }
      } catch (_) {
        if (context.mounted) Toast.show(context, '标记失败，请重试');
      } finally {
        if (mounted) setState(() => _isMarking = false);
      }
    }

    Future<void> markOther() async {
      if (_focusedIndex == null || _focusedIndex! >= students.length) return;
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('其他状态'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '请输入说明（如：迟到、早退…）',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (result != null && result.isNotEmpty) {
        await mark(AttendanceStatus.other, remark: result);
      }
    }

    // 同步失败时禁用所有编辑按钮
    final hasSyncFailed = ref.watch(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.when(
      data: (failed) => failed,
      loading: () => false,
      error: (error, stackTrace) => false,
    );

    final c = context.colors;
    final focused = _focusedIndex != null && _focusedIndex! < students.length
        ? students[_focusedIndex!]
        : null;

    return BottomActionBar(
      hintText: focused != null
          ? '当前学生：${focused.student.name}'
          : '请选择学生',
      primary: AppButton.primary(
        label: '到课',
        onPressed: (!isSyncFailed && !_isMarking && _focusedIndex != null)
            ? markPresent
            : null,
        size: AppButtonSize.lg,
        fullWidth: true,
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _smallActionButton(
            '缺',
            c.stateDanger,
            (!isSyncFailed && !_isMarking && _focusedIndex != null)
                ? () => mark(AttendanceStatus.absent)
                : null,
          ),
          const SizedBox(width: 6),
          _smallActionButton(
            '迟',
            c.stateWarning,
            (!isSyncFailed && !_isMarking && _focusedIndex != null)
                ? () => mark(AttendanceStatus.late_)
                : null,
          ),
          const SizedBox(width: 6),
          _smallActionButton(
            '假',
            c.stateInfo,
            (!isSyncFailed && !_isMarking && _focusedIndex != null)
                ? () => mark(AttendanceStatus.leave)
                : null,
          ),
          const SizedBox(width: 6),
          _smallActionButton(
            '他',
            c.textSecondary,
            (!isSyncFailed && !_isMarking && _focusedIndex != null)
                ? markOther
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出记名'),
        content: const Text('当前记名尚未完成，请选择操作：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('继续记名'),
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
    if (!context.mounted) return;
    switch (result) {
      case 'save':
        context.pop();
      case 'abandon':
        await ref.read(nameCheckProvider.notifier).abandonTask();
        if (context.mounted) context.pop();
      default:
        break;
    }
  }

  Future<void> _showFinishDialog(
    BuildContext context,
    NameCheckState state,
  ) async {
    final pendingCount = state.totalStudents - state.processedStudents;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认名单'),
        content: Text(
          pendingCount > 0
              ? '还有 $pendingCount 人未处理，未处理的将标记为"已到"。确认结束？'
              : '所有学生已处理完毕，确认结束？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _runFinish(forceMarkPending: false);
  }

  /// 执行 finishNameCheck，并按返回结果处理：成功跳转 / 名单变化弹窗 / 失败提示
  Future<void> _runFinish({required bool forceMarkPending}) async {
    final result = await ref
        .read(nameCheckProvider.notifier)
        .finishNameCheck(forceMarkPending: forceMarkPending);
    if (!mounted) return;

    if (result.success) {
      context.push('/confirmation');
      return;
    }

    if (result.isFailed) {
      Toast.show(context, result.errorMessage ?? '结束记名失败，请重试');
      return;
    }

    // 名单发生变化：新增了学生（reconcile 后），交由用户决定
    if (result.hasNewStudents) {
      await _showNewStudentsDialog(result.newStudents!);
    }
  }

  /// 名单变化提示：发现新增学生，让用户选择"返回标记"或"全部按已到处理"
  Future<void> _showNewStudentsDialog(
    Map<int, List<StudentInfo>> newByClass,
  ) async {
    final state = ref.read(nameCheckProvider);
    // 班级 id → 班级名（用于提示）
    final classNameMap = {
      for (final c in state.classes) c.id: c.displayName,
    };
    final totalNew = newByClass.values.fold<int>(0, (s, l) => s + l.length);

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('名单已更新'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('检测到名单新增 $totalNew 名学生（未标记），请选择处理方式：'),
                const SizedBox(height: 12),
                ...newByClass.entries.map((e) {
                  final cls = classNameMap[e.key] ?? '未知班级';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cls,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...e.value.map(
                          (s) => Text('· ${s.name} (${s.studentNo})'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'mark'),
              child: const Text('返回标记'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('全部按已到处理'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == 'force') {
      await _runFinish(forceMarkPending: true);
    } else {
      // 返回标记：跳到第一个新增学生所在班级，让用户继续处理
      final firstClassId = newByClass.keys.first;
      final classIndex =
          state.classes.indexWhere((c) => c.id == firstClassId);
      if (classIndex >= 0) {
        ref.read(nameCheckProvider.notifier).switchClass(classIndex);
        if (state.classes.length > 1) {
          _pageController.animateToPage(
            classIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _focusedIndex = 0);
      }
    }
  }
}

// ============================================================
// 子组件
// ============================================================

class _StudentCard extends StatelessWidget {
  final String name;
  final String studentNo;
  final AttendanceStatus status;
  final String? remark;
  final bool isFocused;
  final VoidCallback onTap;

  const _StudentCard({
    required this.name,
    required this.studentNo,
    required this.status,
    this.remark,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPending = status == AttendanceStatus.pending;
    final bgColor = isFocused
        ? c.brandSubtle
        : (isPending ? c.bgSurface : c.bgMuted);
    final borderColor = isFocused ? c.brandPrimary : c.borderSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurves.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: borderColor,
              width: isFocused ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      studentNo,
                      style: AppTextStyles.withTabular(
                        AppTextStyles.xs,
                      ).copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              if (!isPending) ...[
                const SizedBox(width: 8),
                _statusPillFor(status, remark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPillFor(AttendanceStatus s, String? remark) {
    return switch (s) {
      AttendanceStatus.present => const StatusPill.success(label: '到'),
      AttendanceStatus.absent => const StatusPill.danger(label: '缺'),
      AttendanceStatus.late_ => const StatusPill.warning(label: '迟'),
      AttendanceStatus.leave => const StatusPill.info(label: '假'),
      AttendanceStatus.other => StatusPill.neutral(label: remark ?? '他'),
      AttendanceStatus.pending => const SizedBox.shrink(),
    };
  }
}

class _ClassStudentGrid extends StatelessWidget {
  final List<StudentWithStatus> students;
  final int? focusedIndex;
  final void Function(int index) onTap;

  const _ClassStudentGrid({
    required this.students,
    required this.focusedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = 2;
        final itemWidth = (constraints.maxWidth - 12 * 2 - 8) / crossAxisCount;
        const itemHeight = 56.0;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final sw = students[index];
            final isFocused = focusedIndex == index;

            return RepaintBoundary(
              key: ValueKey(sw.student.id),
              child: _StudentCard(
                name: sw.student.name,
                studentNo: sw.student.studentNo,
                status: sw.status,
                remark: sw.remark,
                isFocused: isFocused,
                onTap: () => onTap(index),
              ),
            );
          },
        );
      },
    );
  }
}
