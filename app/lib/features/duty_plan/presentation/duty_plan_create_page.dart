import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/notification/notification_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../../attendance/domain/models.dart';
import '../domain/duty_plan.dart';

class DutyPlanCreatePage extends ConsumerStatefulWidget {
  const DutyPlanCreatePage({super.key});

  @override
  ConsumerState<DutyPlanCreatePage> createState() => _DutyPlanCreatePageState();
}

class _DutyPlanCreatePageState extends ConsumerState<DutyPlanCreatePage> {
  int? _weekNumber;
  int? _weekday;
  int? _period;
  List<ClassInfo> _allClasses = [];
  List<GradeInfo> _grades = [];
  List<MajorInfo> _majors = [];
  final List<ClassInfo> _selectedClasses = [];
  final _remarkController = TextEditingController();
  DateTime? _semesterStartDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/week/current');
      final data = res.data as Map<String, dynamic>;
      final currentWeek = data['week_number'] as int;
      final startDate = DateTime.parse(data['start_date'] as String);
      final repo = ref.read(studentRepositoryProvider);
      // 主动同步基础数据（年级/专业/班级），避免依赖点名页先加载
      var classes = await repo.getClasses();
      if (classes.isEmpty) {
        try {
          await repo.syncBaseData();
          classes = await repo.getClasses();
        } catch (_) {
          // 网络失败时仍允许进入页面
        }
      }
      final grades = await repo.getGrades();
      final majors = await repo.getMajors();
      if (!mounted) return;
      setState(() {
        _weekNumber = currentWeek;
        _semesterStartDate =
            startDate.subtract(Duration(days: (currentWeek - 1) * 7));
        _allClasses = classes;
        _grades = grades;
        _majors = majors;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, '加载失败: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _weekNumber != null &&
      _weekday != null &&
      _period != null &&
      _selectedClasses.isNotEmpty &&
      _semesterStartDate != null;
  Future<void> _submit() async {
    if (!_canSubmit) return;
    final repo = ref.read(dutyPlanRepositoryProvider);
    final notif = NotificationService();

    final weekStart = _semesterStartDate!
        .add(Duration(days: (_weekNumber! - 1) * 7));
    final classStartAt = DutyPlan.computeClassStartAt(
      startDate: weekStart,
      weekday: _weekday!,
      period: _period!,
    );

    final plan = DutyPlan(
      id: const Uuid().v4(),
      weekNumber: _weekNumber!,
      weekday: _weekday!,
      period: _period!,
      classIds: _selectedClasses.map((c) => c.id.toString()).toList(),
      className: _selectedClasses.map((c) => c.displayName).join('、'),
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      notificationId:
          DutyPlan.computeNotificationId(_weekNumber!, _weekday!, _period!),
      reminderEnabled: true,
      classStartAt: classStartAt,
      createdAt: DateTime.now(),
    );

    final granted = await notif.isPermissionGranted();
    if (!granted) {
      final ok = await notif.requestPermission();
      if (!mounted) return;
      if (!ok) {
        Toast.show(context, '通知权限未开启，提醒可能无法显示。计划仍会保存。');
      }
    }

    await repo.upsert(plan);
    final scheduled = await notif.scheduleDutyReminder(
      notificationId: plan.notificationId,
      title: '查课提醒 · 第${plan.period}节',
      body: '${plan.weekdayLabel} ${plan.timeRange} 即将开始，记得查课',
      scheduledAt: plan.remindAt,
      payload: plan.id,
    );

    if (!mounted) return;
    if (scheduled) {
      Toast.show(context, '已创建，将在上课前 15 分钟提醒');
    } else {
      Toast.show(context, '已创建。提醒时间已过，本次不会发送通知。');
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('新建查课计划')),
      bottomNavigationBar: BottomActionBar(
        primary: AppButton.primary(
          label: '创建并设置提醒',
          onPressed: _canSubmit ? _submit : null,
          fullWidth: true,
          size: AppButtonSize.lg,
          leadingIcon: Icons.alarm_add,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(context, '周次'),
                  _weekPicker(),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel(context, '星期'),
                  _weekdayPicker(),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel(context, '节次'),
                  _periodPicker(),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel(context,
                      '班级 (${_selectedClasses.length}/${_allClasses.length})'),
                  _classPicker(),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel(context, '备注 (可选)'),
                  TextField(
                    controller: _remarkController,
                    decoration: InputDecoration(
                      hintText: '例如：重点查课、配合班主任等',
                      hintStyle:
                          AppTextStyles.sm.copyWith(color: c.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _previewHint(),
                ],
              ),
            ),
    );
  }
  Widget _sectionLabel(BuildContext context, String text) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _weekPicker() {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _weekNumber != null && _weekNumber! > 1
                ? () => setState(() => _weekNumber = _weekNumber! - 1)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                '第 ${_weekNumber ?? "-"} 周',
                style: AppTextStyles.h2.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _weekNumber != null
                ? () => setState(() => _weekNumber = _weekNumber! + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _weekdayPicker() {
    final c = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      children: List.generate(5, (i) {
        final wd = i + 1;
        final selected = _weekday == wd;
        return ChoiceChip(
          label: Text(kWeekdayLabels[wd]!),
          selected: selected,
          onSelected: (_) => setState(() => _weekday = wd),
          selectedColor: c.brandSubtle,
          labelStyle: AppTextStyles.sm.copyWith(
            color: selected ? c.brandPrimary : c.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          backgroundColor: c.bgSurface,
          side: BorderSide(
            color: selected ? c.brandPrimary : c.borderDefault,
          ),
        );
      }),
    );
  }

  Widget _periodPicker() {
    final c = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: kPeriodSchedules.map((p) {
        final selected = _period == p.period;
        return InkWell(
          onTap: () => setState(() => _period = p.period),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? c.brandSubtle : c.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? c.brandPrimary : c.borderDefault,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '第${p.period}节',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected ? c.brandPrimary : c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.timeRange,
                  style: AppTextStyles.withTabular(AppTextStyles.xs).copyWith(
                    color: selected ? c.brandPrimary : c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  Widget _classPicker() {
    final c = context.colors;
    if (_allClasses.isEmpty) {
      return Text(
        '暂无可选班级',
        style: AppTextStyles.sm.copyWith(color: c.textTertiary),
      );
    }
    return GestureDetector(
      onTap: () => _showClassDialog(),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.class_outlined, size: 18, color: c.brandPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedClasses.isEmpty
                        ? '点击选择班级'
                        : '已选 ${_selectedClasses.length} 个班级',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedClasses.isEmpty
                          ? c.textTertiary
                          : c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedClasses.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _selectedClasses.map((c) => c.displayName).join('、'),
                      style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showClassDialog() {
    final gradeMap = <int, GradeInfo>{};
    for (final g in _grades) gradeMap[g.id] = g;
    final majorMap = <int, MajorInfo>{};
    for (final m in _majors) majorMap[m.id] = m;

    // 按年级+专业分组
    final grouped = <String, List<ClassInfo>>{};
    for (final cls in _allClasses) {
      final g = gradeMap[cls.gradeId];
      final m = majorMap[cls.majorId];
      final key = '${g?.name ?? '其他'} ${m?.shortName ?? ''}';
      grouped.putIfAbsent(key, () => []).add(cls);
    }
    final keys = grouped.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) {
        final dc = ctx.colors;
        return AlertDialog(
          title: Text(
            '选择班级 (${_selectedClasses.length})',
            style: AppTextStyles.h3.copyWith(color: dc.textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 已选班级 header
                if (_selectedClasses.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: dc.brandSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedClasses
                                .map((c) => c.displayName)
                                .join('、'),
                            style: AppTextStyles.sm.copyWith(
                              color: dc.brandPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => _selectedClasses.clear());
                          },
                          child: Text('清除',
                              style: AppTextStyles.sm
                                  .copyWith(color: dc.stateDanger)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Expanded(
                  child: ListView(
                    children: keys.map((key) {
                      final classList = grouped[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Text(
                              key,
                              style: AppTextStyles.xs.copyWith(
                                color: dc.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: classList.map((cls) {
                              final selected =
                                  _selectedClasses.any((s) => s.id == cls.id);
                              return FilterChip(
                                label: Text(cls.displayName),
                                selected: selected,
                                onSelected: (on) {
                                  setState(() {
                                    if (on) {
                                      _selectedClasses.add(cls);
                                    } else {
                                      _selectedClasses
                                          .removeWhere((s) => s.id == cls.id);
                                    }
                                  });
                                },
                                selectedColor: dc.brandSubtle,
                                checkmarkColor: dc.brandPrimary,
                                labelStyle: AppTextStyles.sm.copyWith(
                                  color: selected
                                      ? dc.brandPrimary
                                      : dc.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                                backgroundColor: dc.bgSurface,
                                side: BorderSide(
                                  color:
                                      selected ? dc.brandPrimary : dc.borderDefault,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('完成'),
            ),
          ],
        );
      },
    );
  }

  Widget _previewHint() {
    final c = context.colors;
    if (!_canSubmit) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.bgMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: c.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '请完成上方选择后查看预览',
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final weekStart = _semesterStartDate!
        .add(Duration(days: (_weekNumber! - 1) * 7));
    final classStartAt = DutyPlan.computeClassStartAt(
      startDate: weekStart,
      weekday: _weekday!,
      period: _period!,
    );
    final remindAt = classStartAt.subtract(const Duration(minutes: 15));

    String two(int n) => n.toString().padLeft(2, '0');
    String fmtDateTime(DateTime t) =>
        '${t.month}月${t.day}日 ${two(t.hour)}:${two(t.minute)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.brandPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm, size: 18, color: c.brandPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '提醒预览',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: c.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '上课时间: ${fmtDateTime(classStartAt)}',
            style: AppTextStyles.sm.copyWith(color: c.textPrimary),
          ),
          Text(
            '提醒时间: ${fmtDateTime(remindAt)}（上课前 15 分钟）',
            style: AppTextStyles.sm.copyWith(color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}