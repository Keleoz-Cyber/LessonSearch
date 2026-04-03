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
  ClassInfo? _selectedClass;

  bool _loading = true;
  String? _error;

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
      _selectedClass = null;
      _classes = [];
    });
  }

  Future<void> _onMajorChanged(MajorInfo? major) async {
    setState(() {
      _selectedMajor = major;
      _selectedClass = null;
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
    if (_selectedClass == null) return;
    context.push(
      '/roll-call/execute',
      extra: {
        'classId': _selectedClass!.id,
        'gradeId': _selectedGrade!.id,
        'majorId': _selectedMajor!.id,
        'className': _selectedClass!.displayName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.taskType == TaskType.rollCall ? '点名' : '记名';

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

            // 班级
            DropdownButtonFormField<ClassInfo>(
              decoration: const InputDecoration(
                labelText: '班级',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedClass,
              items: _classes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.displayName)))
                  .toList(),
              onChanged: (c) => setState(() => _selectedClass = c),
            ),

            const Spacer(),

            // 开始按钮
            FilledButton.icon(
              onPressed: _selectedClass != null ? _startTask : null,
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
}
