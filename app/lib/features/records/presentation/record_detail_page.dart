import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../data/records_repository.dart';
import '../../attendance/domain/models.dart';
import '../../attendance/domain/text_template.dart';

class RecordDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const RecordDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends ConsumerState<RecordDetailPage> {
  List<RecordEntry> _entries = [];
  String? _taskDate;
  bool _loading = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(recordsRepositoryProvider);
    final entries = await repo.getRecordEntries(widget.taskId);
    // 获取任务创建时间
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final task = await attendanceRepo.getTask(widget.taskId);
    setState(() {
      _entries = entries;
      _taskDate = task != null
          ? task.createdAt.toString().substring(0, 16)
          : DateTime.now().toString().substring(0, 16);
      _loading = false;
    });
  }

  Future<void> _updateStatus(int recordId, int index, AttendanceStatus newStatus, {String? remark}) async {
    final repo = ref.read(recordsRepositoryProvider);
    await repo.updateRecord(recordId, newStatus, remark: remark);
    await _load();
  }

  void _generateText() {
    final date = _taskDate ?? DateTime.now().toString().substring(0, 16);

    // 按班级分组
    final byClass = <String, List<RecordEntry>>{};
    for (final e in _entries) {
      byClass.putIfAbsent(e.className, () => []).add(e);
    }

    final classStatsList = <ClassStats>[];
    final allAbsent = <StudentRecord>[];
    final allLeave = <StudentRecord>[];
    final allOther = <StudentRecord>[];
    final classNames = <String>[];

    for (final entry in byClass.entries) {
      classNames.add(entry.key);
      final students = entry.value;
      final absent = students.where((s) => s.status == AttendanceStatus.absent).toList();
      final leave = students.where((s) => s.status == AttendanceStatus.leave).toList();
      final other = students.where((s) => s.status == AttendanceStatus.other).toList();
      final present = students.length - absent.length - leave.length - other.length;

      toRecord(RecordEntry e) => StudentRecord(
            name: e.studentName,
            studentNo: e.studentNo,
            className: e.className,
            remark: e.remark,
          );

      allAbsent.addAll(absent.map(toRecord));
      allLeave.addAll(leave.map(toRecord));
      allOther.addAll(other.map(toRecord));

      classStatsList.add(ClassStats(
        className: entry.key,
        total: students.length,
        present: present,
        absent: absent.length,
        leave: leave.length,
        other: other.length,
        absentStudents: absent.map(toRecord).toList(),
        leaveStudents: leave.map(toRecord).toList(),
        otherStudents: other.map(toRecord).toList(),
      ));
    }

    final stats = AttendanceStats(
      date: date,
      classNames: classNames,
      total: _entries.length,
      present: _entries.length - allAbsent.length - allLeave.length - allOther.length,
      absent: allAbsent.length,
      leave: allLeave.length,
      other: allOther.length,
      absentStudents: allAbsent,
      leaveStudents: allLeave,
      otherStudents: allOther,
    );

    final groupReport = generateGroupReport(stats);
    final committeeReport = generateCommitteeReport(classStatsList, date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TextSheet(
        groupReport: groupReport,
        committeeReport: committeeReport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('记录详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 按班级分组，只显示异常
    final abnormal = _editing
        ? _entries
        : _entries.where((e) => e.status != AttendanceStatus.present).toList();

    final byClass = <String, List<RecordEntry>>{};
    for (final e in abnormal) {
      byClass.putIfAbsent(e.className, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
        actions: [
          TextButton.icon(
            icon: Icon(_editing ? Icons.check : Icons.edit),
            label: Text(_editing ? '完成' : '编辑'),
            onPressed: () => setState(() => _editing = !_editing),
          ),
          IconButton(
            icon: const Icon(Icons.text_snippet),
            tooltip: '生成文本',
            onPressed: _generateText,
          ),
        ],
      ),
      body: abnormal.isEmpty
          ? Center(
              child: Text(
                _editing ? '没有记录' : '全部到齐，没有异常记录',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: byClass.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...entry.value.asMap().entries.map((e) {
                      final idx = e.key;
                      final record = e.value;
                      return _RecordRow(
                        entry: record,
                        editing: _editing,
                        onStatusChanged: (status, {remark}) =>
                            _updateStatus(record.recordId, idx, status, remark: remark),
                      );
                    }),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final RecordEntry entry;
  final bool editing;
  final Function(AttendanceStatus status, {String? remark}) onStatusChanged;

  const _RecordRow({
    required this.entry,
    required this.editing,
    required this.onStatusChanged,
  });

  Color get _color => switch (entry.status) {
        AttendanceStatus.present => Colors.green,
        AttendanceStatus.absent => Colors.red,
        AttendanceStatus.leave => Colors.orange,
        AttendanceStatus.other => Colors.purple,
        AttendanceStatus.pending => Colors.grey,
      };

  String get _label => switch (entry.status) {
        AttendanceStatus.present => '到',
        AttendanceStatus.absent => '缺勤',
        AttendanceStatus.leave => '请假',
        AttendanceStatus.other => entry.remark ?? '其他',
        AttendanceStatus.pending => '待查',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(entry.studentName)),
          Expanded(
            flex: 3,
            child: Text(entry.studentNo, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          if (editing)
            PopupMenuButton<AttendanceStatus>(
              initialValue: entry.status,
              onSelected: (status) {
                if (status == AttendanceStatus.other) {
                  _showRemarkDialog(context);
                } else {
                  onStatusChanged(status);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: AttendanceStatus.present, child: Text('到课')),
                const PopupMenuItem(value: AttendanceStatus.absent, child: Text('缺勤')),
                const PopupMenuItem(value: AttendanceStatus.leave, child: Text('请假')),
                const PopupMenuItem(value: AttendanceStatus.other, child: Text('其他...')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_label, style: TextStyle(color: _color, fontSize: 13)),
                    Icon(Icons.arrow_drop_down, size: 16, color: _color),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_label, style: TextStyle(color: _color, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  void _showRemarkDialog(BuildContext context) {
    final controller = TextEditingController(text: entry.remark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('其他状态'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入说明',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChanged(AttendanceStatus.other, remark: controller.text.trim());
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

class _TextSheet extends StatelessWidget {
  final String groupReport;
  final String committeeReport;

  const _TextSheet({required this.groupReport, required this.committeeReport});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollController) {
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(tabs: [Tab(text: '总群汇报'), Tab(text: '学委汇报')]),
              Expanded(
                child: TabBarView(
                  children: [
                    _copyableText(context, groupReport, '总群汇报'),
                    _copyableText(context, committeeReport, '学委汇报'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _copyableText(BuildContext context, String text, String label) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(text, style: const TextStyle(fontSize: 14, height: 1.6)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已复制$label'), duration: const Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text('复制$label'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ),
      ],
    );
  }
}
