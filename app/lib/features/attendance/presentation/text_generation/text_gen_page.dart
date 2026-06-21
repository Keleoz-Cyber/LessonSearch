import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/app_card.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/design_system/widgets/segmented_control.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/toast.dart';
import '../../../attendance/domain/models.dart';
import '../../../attendance/domain/text_template.dart';
import '../../../extension/presentation/submission_page.dart';

class TextGenPage extends ConsumerStatefulWidget {
  final String taskId;

  const TextGenPage({super.key, required this.taskId});

  @override
  ConsumerState<TextGenPage> createState() => _TextGenPageState();
}

class _TextGenPageState extends ConsumerState<TextGenPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _groupReport = '';
  List<ClassStats> _classStatsList = [];
  bool _generated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _generateTexts();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _generateTexts() {
    final state = ref.read(nameCheckProvider);
    final taskTime = state.task?.createdAt ?? DateTime.now();
    final date = taskTime.toString().substring(0, 16);

    final classStatsList = <ClassStats>[];

    for (final cls in state.classes) {
      final students = state.studentsByClass[cls.id] ?? [];

      final classAbsent = <StudentRecord>[];
      final classLate = <StudentRecord>[];
      final classLeave = <StudentRecord>[];
      final classOther = <StudentRecord>[];
      var classPresent = 0;

      for (final sw in students) {
        final record = StudentRecord(
          name: sw.student.name,
          studentNo: sw.student.studentNo,
          className: cls.displayName,
          remark: sw.remark,
        );

        switch (sw.status) {
          case AttendanceStatus.present:
            classPresent++;
          case AttendanceStatus.absent:
            classAbsent.add(record);
          case AttendanceStatus.late_:
            classLate.add(record);
            classPresent++;
          case AttendanceStatus.leave:
            classLeave.add(record);
          case AttendanceStatus.other:
            classOther.add(record);
          case AttendanceStatus.pending:
            classPresent++;
        }
      }

      classStatsList.add(
        ClassStats(
          className: cls.displayName,
          total: students.length,
          present: classPresent,
          absent: classAbsent.length,
          late_: classLate.length,
          leave: classLeave.length,
          other: classOther.length,
          absentStudents: classAbsent,
          lateStudents: classLate,
          leaveStudents: classLeave,
          otherStudents: classOther,
        ),
      );
    }

    setState(() {
      _groupReport = generateGroupReport(classStatsList, date);
      _classStatsList = classStatsList;
      _generated = true;
    });
  }

  String _generateClassCommitteeReport(ClassStats cs, String date) {
    return defaultCommitteeReportTemplate
        .replaceAll('{date}', date)
        .replaceAll('{class_name}', cs.className)
        .replaceAll('{total}', '${cs.total}')
        .replaceAll('{present}', '${cs.present}')
        .replaceAll('{absent}', '${cs.absent}')
        .replaceAll('{late}', '${cs.late_}')
        .replaceAll('{leave}', '${cs.leave}')
        .replaceAll('{other}', '${cs.other}')
        .replaceAll('{absent_names}', _formatNames(cs.absentStudents))
        .replaceAll('{late_names}', _formatNames(cs.lateStudents))
        .replaceAll('{leave_names}', _formatNames(cs.leaveStudents))
        .replaceAll('{other_names}', _formatNamesWithRemark(cs.otherStudents))
        .trim();
  }

  String _formatNames(List<StudentRecord> students) {
    if (students.isEmpty) return '无';
    return students.map((s) => s.name).join('、');
  }

  String _formatNamesWithRemark(List<StudentRecord> students) {
    if (students.isEmpty) return '无';
    return students
        .map((s) => s.remark != null ? '${s.name}(${s.remark})' : s.name)
        .join('、');
  }

  void _copyAndOpenApp(String text, bool isWechat, {bool confirm = false}) async {
    final c = context.colors;
    if (confirm) {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.info_outline, color: c.brandPrimary, size: 40),
          title: const Text('复制汇报文本'),
          content: const Text(
            '确认复制最终汇报文本？\n\n'
            '复制后请前往"扩展功能 → 名单提交"完成提交审核。\n'
            '提交后如需修改，请先撤回。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认复制'),
            ),
          ],
        ),
      );
      if (result != true) return;
    }

    Clipboard.setData(ClipboardData(text: text));
    if (mounted) Toast.show(context, '已复制到剪贴板');

    await Future.delayed(const Duration(milliseconds: 300));

    final uri = Uri.parse(isWechat ? 'weixin://' : 'mqq://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        Toast.show(context, isWechat ? '未安装微信' : '未安装QQ');
      }
    }
  }

  Future<void> _finish() async {
    final weekData = await ref.read(currentWeekProvider.future);
    final weekNumber = weekData['week_number'] as int;
    ref.invalidate(weekNameCheckTasksProvider(weekNumber));
    ref.invalidate(submittedTaskIdsProvider);
    context.go('/');
  }

  Future<bool> _onWillPop() async {
    if (!_generated) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提示'),
        content: const Text('是否已复制所需文本？直接退出不会丢失数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回复制'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          final weekData = await ref.read(currentWeekProvider.future);
          final weekNumber = weekData['week_number'] as int;
          ref.invalidate(weekNameCheckTasksProvider(weekNumber));
          ref.invalidate(submittedTaskIdsProvider);
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: AppBar(title: const Text('生成汇报文本')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: AppSegmentedControl<int>(
                items: const [
                  AppSegmentedItem(value: 0, label: '学委汇报'),
                  AppSegmentedItem(value: 1, label: '总群汇报'),
                ],
                value: _tabController.index,
                onChanged: (i) {
                  _tabController.animateTo(i);
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCommitteeReportView(),
                  _buildGroupReportView(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          primary: AppButton.gradient(
            label: '完成',
            onPressed: _finish,
            size: AppButtonSize.lg,
            fullWidth: true,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupReportView() {
    final c = context.colors;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SelectableText(
                _groupReport,
                style: AppTextStyles.body.copyWith(
                  color: c.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: AppButton.primary(
            label: '复制并打开微信',
            onPressed: () => _copyAndOpenApp(_groupReport, true, confirm: true),
            leadingIcon: Icons.wechat,
            size: AppButtonSize.lg,
            fullWidth: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCommitteeReportView() {
    final c = context.colors;
    final state = ref.read(nameCheckProvider);
    final taskTime = state.task?.createdAt ?? DateTime.now();
    final date = taskTime.toString().substring(0, 16);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _classStatsList.length,
      itemBuilder: (context, index) {
        final cs = _classStatsList[index];
        final text = _generateClassCommitteeReport(cs, date);

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cs.className,
                          style: AppTextStyles.h3.copyWith(
                            color: c.textPrimary,
                          ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton.primary(
                      label: '复制',
                      onPressed: () => _copyAndOpenApp(text, false),
                      leadingIcon: Icons.copy,
                      size: AppButtonSize.sm,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  text,
                  style: AppTextStyles.body.copyWith(
                    color: c.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
