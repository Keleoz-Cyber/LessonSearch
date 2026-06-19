import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/design_system/colors.dart';
import '../../../../shared/design_system/tokens.dart';
import '../../../../shared/design_system/typography.dart';
import '../../../../shared/design_system/widgets/app_button.dart';
import '../../../../shared/design_system/widgets/app_card.dart';
import '../../../../shared/design_system/widgets/bottom_action_bar.dart';
import '../../../../shared/providers.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../attendance/domain/models.dart';

class SelectionPage extends ConsumerStatefulWidget {
  final TaskType taskType;

  const SelectionPage({super.key, required this.taskType});

  @override
  ConsumerState<SelectionPage> createState() => _SelectionPageState();
}

class _SelectionPageState extends ConsumerState<SelectionPage> {
  List<GradeInfo> _grades = [];
  List<MajorInfo> _majors = [];
  List<ClassInfo> _classes = [];

  GradeInfo? _selectedGrade;
  MajorInfo? _selectedMajor;
  final Set<int> _selectedClassIds = {};

  bool _loading = true;
  String? _error;

  bool get _isNameCheck => widget.taskType == TaskType.nameCheck;

  bool get _canStart => _selectedClassIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadBaseData();
  }

  Future<void> _loadBaseData() async {
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.ensureBaseData();
      final grades = await repo.getGrades();
      final majors = await repo.getMajors();
      setState(() {
        _grades = grades;
        _majors = majors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _formatError(e);
        _loading = false;
      });
    }
  }

  static String _formatError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('timed out') ||
        msg.contains('network') ||
        msg.contains('Network')) {
      return '网络连接失败，请检查网络后重试';
    }
    return '加载数据失败: $e';
  }

  Future<void> _onGradeChanged(GradeInfo? grade) async {
    setState(() {
      _selectedGrade = grade;
      _selectedMajor = null;
      _selectedClassIds.clear();
      _classes = [];
    });
  }

  Future<void> _onMajorChanged(MajorInfo? major) async {
    setState(() {
      _selectedMajor = major;
      _selectedClassIds.clear();
    });
    if (_selectedGrade != null && major != null) {
      final repo = ref.read(studentRepositoryProvider);
      final classes = await repo.getClasses(
        gradeId: _selectedGrade!.id,
        majorId: major.id,
      );
      setState(() => _classes = classes);
    }
  }

  void _startTask() {
    if (!_canStart) return;

    final selectedClasses = _classes
        .where((c) => _selectedClassIds.contains(c.id))
        .toList();
    final route = _isNameCheck ? '/name-check/execute' : '/roll-call/execute';

    context.push(
      route,
      extra: {
        'classIds': selectedClasses.map((c) => c.id).toList(),
        'classNames': selectedClasses.map((c) => c.displayName).toList(),
        'gradeId': _selectedGrade!.id,
        'majorId': _selectedMajor!.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = _isNameCheck ? '记名' : '点名';

    if (_error != null) {
      return Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: AppBar(title: Text('$title - 选择班级')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: c.stateDanger,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _error!,
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton.primary(
                  label: '重试',
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadBaseData();
                  },
                  leadingIcon: Icons.refresh,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: Text('$title - 选择班级')),
      body: LoadingOverlay(
        isLoading: _loading,
        message: '加载数据中...',
        child: Column(
          children: [
            // 年级选择
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: DropdownButtonFormField<GradeInfo>(
                decoration: const InputDecoration(
                  labelText: '年级',
                ),
                initialValue: _selectedGrade,
                items: _grades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                    .toList(),
                onChanged: _onGradeChanged,
              ),
            ),

            // 专业选择
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: DropdownButtonFormField<MajorInfo>(
                decoration: const InputDecoration(
                  labelText: '专业',
                ),
                initialValue: _selectedMajor,
                items: _majors
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text(m.shortName)),
                    )
                    .toList(),
                onChanged: _selectedGrade != null ? _onMajorChanged : null,
              ),
            ),

            // 班级选择
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _buildClassSelector(),
              ),
            ),

            // 底部按钮区域
            BottomActionBar(
              hintText: _selectedClassIds.isEmpty
                  ? '请选择至少一个班级'
                  : '已选 ${_selectedClassIds.length} 个班级',
              primary: AppButton.gradient(
                label: '开始$title',
                onPressed: _canStart ? _startTask : null,
                leadingIcon: Icons.play_arrow,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelector() {
    final c = context.colors;

    Widget header({Widget? trailing}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Text(
              '班级（多选）',
              style: AppTextStyles.sm.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
      );
    }

    // 未选择专业
    if (_selectedMajor == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bgSurface,
              border: Border.all(color: c.borderSubtle),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.class_outlined, size: 32, color: c.textTertiary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '请先选择年级和专业',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 选择专业后无班级
    if (_classes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bgSurface,
              border: Border.all(color: c.borderSubtle),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '该专业暂无班级数据',
              style: AppTextStyles.sm.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      );
    }

    // 有班级可选
    final allSelected = _selectedClassIds.length == _classes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header(
          trailing: AppButton.ghost(
            label: allSelected ? '取消全选' : '全选',
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedClassIds.clear();
                } else {
                  _selectedClassIds.addAll(_classes.map((c) => c.id));
                }
              });
            },
            size: AppButtonSize.sm,
          ),
        ),
        ..._classes.map((cls) {
          final selected = _selectedClassIds.contains(cls.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              selected: selected,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedClassIds.remove(cls.id);
                  } else {
                    _selectedClassIds.add(cls.id);
                  }
                });
              },
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? c.brandPrimary : c.borderStrong,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      cls.displayName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
