import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers.dart';
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
        _error = '加载数据失败: $e';
        _loading = false;
      });
    }
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

    final selectedClasses =
        _classes.where((c) => _selectedClassIds.contains(c.id)).toList();
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
    final title = _isNameCheck ? '记名' : '点名';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('$title - 选择班级')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('$title - 选择班级')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _loadBaseData();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('$title - 选择班级')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 年级
            DropdownButtonFormField<GradeInfo>(
              decoration: const InputDecoration(
                labelText: '年级',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedGrade,
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                  .toList(),
              onChanged: _onGradeChanged,
            ),
            const SizedBox(height: 16),

            // 专业
            DropdownButtonFormField<MajorInfo>(
              decoration: const InputDecoration(
                labelText: '专业',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedMajor,
              items: _majors
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.shortName)))
                  .toList(),
              onChanged: _selectedGrade != null ? _onMajorChanged : null,
            ),
            const SizedBox(height: 16),

            // 班级多选
            _buildMultiSelectClasses(),

            const Spacer(),

            // 选中数量提示（记名模式）
            if (_selectedClassIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '已选 ${_selectedClassIds.length} 个班级',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),

            // 开始按钮
            FilledButton.icon(
              onPressed: _canStart ? _startTask : null,
              icon: const Icon(Icons.play_arrow),
              label: Text('开始$title'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectClasses() {
    if (_classes.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: '班级（多选）',
          border: OutlineInputBorder(),
        ),
        child: Text(
          _selectedMajor == null ? '请先选择专业' : '该专业暂无班级',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    final allSelected = _selectedClassIds.length == _classes.length;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: '班级（多选）',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        suffixIcon: TextButton(
          onPressed: () {
            setState(() {
              if (allSelected) {
                _selectedClassIds.clear();
              } else {
                _selectedClassIds.addAll(_classes.map((c) => c.id));
              }
            });
          },
          child: Text(allSelected ? '取消全选' : '全选'),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _classes.map((c) {
          final selected = _selectedClassIds.contains(c.id);
          return FilterChip(
            label: Text(c.displayName),
            selected: selected,
            onSelected: (val) {
              setState(() {
                if (val) {
                  _selectedClassIds.add(c.id);
                } else {
                  _selectedClassIds.remove(c.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }
}
