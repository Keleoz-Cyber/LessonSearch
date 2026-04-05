import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
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
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    return _buildExecutingView(context, state);
  }

  Widget _buildExecutingView(BuildContext context, NameCheckState state) {
    final currentClass = state.currentClass;
    final students = state.currentStudents;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitDialog(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(currentClass?.displayName ?? ''),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitDialog(context),
          ),
          actions: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '${state.processedStudents}/${state.totalStudents}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: '确认名单',
              onPressed: () => _showFinishDialog(context, state),
            ),
          ],
        ),
        body: Column(
          children: [
            // 班级切换标签
            if (state.classes.length > 1)
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  itemCount: state.classes.length,
                  itemBuilder: (context, index) {
                    final cls = state.classes[index];
                    final isActive = index == state.currentClassIndex;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        label: Text(cls.displayName),
                        selected: isActive,
                        onSelected: (_) {
                          ref
                              .read(nameCheckProvider.notifier)
                              .switchClass(index);
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                          );
                          setState(() => _focusedIndex = 0);
                        },
                      ),
                    );
                  },
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
                        final crossAxisCount = constraints.maxWidth > 400
                            ? 2
                            : 1;
                        final itemWidth =
                            (constraints.maxWidth -
                                12 * 2 -
                                8 * (crossAxisCount - 1)) /
                            crossAxisCount;
                        final itemHeight = 56.0;
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

    void mark(AttendanceStatus status, {String? remark}) {
      if (_focusedIndex == null || _focusedIndex! >= students.length) return;
      ref.read(feedbackServiceProvider).feedback();
      ref
          .read(nameCheckProvider.notifier)
          .markStudent(classId, _focusedIndex!, status, remark: remark);

      // 查找当前班级下一个待处理学生
      final nextIndex = students.indexWhere(
        (s) => s.status == AttendanceStatus.pending,
        _focusedIndex! + 1,
      );

      if (nextIndex >= 0) {
        setState(() => _focusedIndex = nextIndex);
      } else if (state.classes.length > 1) {
        // 当前班级已全部处理，切换到下一个班级
        final nextClassIndex = state.currentClassIndex + 1;
        if (nextClassIndex < state.classes.length) {
          final nextClass = state.classes[nextClassIndex];
          final nextClassStudents = state.studentsByClass[nextClass.id] ?? [];
          final firstPending = nextClassStudents.indexWhere(
            (s) => s.status == AttendanceStatus.pending,
          );

          ref.read(nameCheckProvider.notifier).switchClass(nextClassIndex);
          _pageController.animateToPage(
            nextClassIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
          setState(() => _focusedIndex = firstPending >= 0 ? firstPending : 0);
        } else {
          // 已经是最后一个班级，保持当前焦点
          setState(() => _focusedIndex = _focusedIndex);
        }
      } else {
        // 单班级，保持当前焦点
        setState(() => _focusedIndex = _focusedIndex);
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
        mark(AttendanceStatus.other, remark: result);
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: '缺勤',
                    color: Colors.red,
                    onPressed: _focusedIndex != null
                        ? () => mark(AttendanceStatus.absent)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '迟到',
                    color: Colors.amber.shade700,
                    onPressed: _focusedIndex != null
                        ? () => mark(AttendanceStatus.late_)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '请假',
                    color: Colors.blue,
                    onPressed: _focusedIndex != null
                        ? () => mark(AttendanceStatus.leave)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: '其他',
                    color: Colors.grey,
                    onPressed: _focusedIndex != null ? () => markOther() : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _focusedIndex != null
                    ? () => mark(AttendanceStatus.present)
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('到课（下一位）'),
              ),
            ),
          ],
        ),
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
    if (!mounted) return;
    switch (result) {
      case 'save':
        context.pop();
      case 'abandon':
        await ref.read(nameCheckProvider.notifier).abandonTask();
        if (mounted) context.pop();
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
    if (confirm == true) {
      await ref.read(nameCheckProvider.notifier).finishNameCheck();
      if (mounted) context.push('/confirmation');
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

  static const _statusLabels = {
    AttendanceStatus.present: '到',
    AttendanceStatus.absent: '缺',
    AttendanceStatus.late_: '迟',
    AttendanceStatus.leave: '假',
  };

  static Color _statusColor(AttendanceStatus status, bool isDark) {
    return switch (status) {
      AttendanceStatus.pending =>
        isDark ? const Color(0xFF424242) : const Color(0xFFEEEEEE),
      AttendanceStatus.present =>
        isDark ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9),
      AttendanceStatus.absent =>
        isDark ? const Color(0xFFB71C1C) : const Color(0xFFFFCDD2),
      AttendanceStatus.late_ =>
        isDark ? const Color(0xFFF57F17) : const Color(0xFFFFECB3),
      AttendanceStatus.leave =>
        isDark ? const Color(0xFF0D47A1) : const Color(0xFFBBDEFB),
      AttendanceStatus.other =>
        isDark ? const Color(0xFF4A148C) : const Color(0xFFE1BEE7),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _statusColor(status, isDark);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final statusLabel = status == AttendanceStatus.other
        ? (remark ?? '他')
        : _statusLabels[status] ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isFocused
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        studentNo,
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ),
                ),
                if (statusLabel.isNotEmpty)
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: onPressed != null ? color : Colors.grey.shade300,
        ),
        minimumSize: const Size(56, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
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
        final crossAxisCount = constraints.maxWidth > 400 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - 12 * 2 - 8 * (crossAxisCount - 1)) /
            crossAxisCount;
        final itemHeight = 56.0;
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
