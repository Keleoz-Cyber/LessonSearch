import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
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
  TaskType? _taskType;
  bool _loading = true;
  bool _editing = false;

  bool get _isRollCall => _taskType == TaskType.rollCall;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(recordsRepositoryProvider);
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final task = await attendanceRepo.getTask(widget.taskId);

    // 点名用全员列表，记名用记录列表
    final isRollCall = task?.type == TaskType.rollCall;
    final entries = isRollCall
        ? await repo.getFullRollCallEntries(widget.taskId)
        : await repo.getRecordEntries(widget.taskId);

    setState(() {
      _entries = entries;
      _taskType = task?.type;
      _taskDate = task != null
          ? task.createdAt.toString().substring(0, 16)
          : DateTime.now().toString().substring(0, 16);
      _loading = false;
    });
  }

  Future<void> _updateStatus(
    int recordId,
    int index,
    AttendanceStatus newStatus, {
    String? remark,
  }) async {
    final repo = ref.read(recordsRepositoryProvider);
    await repo.updateRecord(recordId, newStatus, remark: remark);
    await _load();
  }

  void _generateText() {
    final date = _taskDate ?? DateTime.now().toString().substring(0, 16);

    final byClass = <String, List<RecordEntry>>{};
    for (final e in _entries) {
      byClass.putIfAbsent(e.className, () => []).add(e);
    }

    final classStatsList = <ClassStats>[];

    for (final entry in byClass.entries) {
      final students = entry.value;
      final absent = students
          .where((s) => s.status == AttendanceStatus.absent)
          .toList();
      final late_ = students
          .where((s) => s.status == AttendanceStatus.late_)
          .toList();
      final leave = students
          .where((s) => s.status == AttendanceStatus.leave)
          .toList();
      final other = students
          .where((s) => s.status == AttendanceStatus.other)
          .toList();
      final present =
          students.length -
          absent.length -
          late_.length -
          leave.length -
          other.length;

      toRecord(RecordEntry e) => StudentRecord(
        name: e.studentName,
        studentNo: e.studentNo,
        className: e.className,
        remark: e.remark,
      );

      classStatsList.add(
        ClassStats(
          className: entry.key,
          total: students.length,
          present: present,
          absent: absent.length,
          late_: late_.length,
          leave: leave.length,
          other: other.length,
          absentStudents: absent.map(toRecord).toList(),
          lateStudents: late_.map(toRecord).toList(),
          leaveStudents: leave.map(toRecord).toList(),
          otherStudents: other.map(toRecord).toList(),
        ),
      );
    }

    final groupReport = generateGroupReport(classStatsList, date);
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

    if (_isRollCall) {
      return _buildRollCallView(context);
    }
    return _buildNameCheckView(context);
  }

  // ============================================================
  // 点名记录：只读，显示已点/未点
  // ============================================================

  Widget _buildRollCallView(BuildContext context) {
    final calledEntries = _entries
        .where((e) => e.status == AttendanceStatus.present)
        .toList();
    final notCalledCount = _entries.length - calledEntries.length;

    // 按班级分组
    final byClass = <String, List<RecordEntry>>{};
    for (final e in _entries) {
      byClass.putIfAbsent(e.className, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('点名记录')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Text(
              '共 ${_entries.length} 人，已点 ${calledEntries.length} 人，未点 $notCalledCount 人',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: byClass.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...entry.value.map((record) {
                      final called = record.status == AttendanceStatus.present;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(record.studentName)),
                            Expanded(
                              flex: 3,
                              child: Text(
                                record.studentNo,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (called ? Colors.green : Colors.grey)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                called ? '已点' : '未点',
                                style: TextStyle(
                                  color: called ? Colors.green : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 记名记录：可编辑，详细状态
  // ============================================================

  Widget _buildNameCheckView(BuildContext context) {
    final abnormal = _editing
        ? _entries
        : _entries.where((e) => e.status != AttendanceStatus.present).toList();

    final byClass = <String, List<RecordEntry>>{};
    for (final e in abnormal) {
      byClass.putIfAbsent(e.className, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('记名详情'),
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...entry.value.asMap().entries.map((e) {
                      final idx = e.key;
                      final record = e.value;
                      return _RecordRow(
                        entry: record,
                        editing: _editing,
                        onStatusChanged: (status, {remark}) => _updateStatus(
                          record.recordId,
                          idx,
                          status,
                          remark: remark,
                        ),
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
    AttendanceStatus.late_ => Colors.amber.shade700,
    AttendanceStatus.leave => Colors.blue,
    AttendanceStatus.other => Colors.purple,
    AttendanceStatus.pending => Colors.grey,
  };

  String get _label => switch (entry.status) {
    AttendanceStatus.present => '到',
    AttendanceStatus.absent => '缺勤',
    AttendanceStatus.late_ => '迟到',
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
            child: Text(
              entry.studentNo,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
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
                const PopupMenuItem(
                  value: AttendanceStatus.present,
                  child: Text('到课'),
                ),
                const PopupMenuItem(
                  value: AttendanceStatus.absent,
                  child: Text('缺勤'),
                ),
                const PopupMenuItem(
                  value: AttendanceStatus.late_,
                  child: Text('迟到'),
                ),
                const PopupMenuItem(
                  value: AttendanceStatus.leave,
                  child: Text('请假'),
                ),
                const PopupMenuItem(
                  value: AttendanceStatus.other,
                  child: Text('其他...'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              child: Text(
                _label,
                style: TextStyle(color: _color, fontSize: 13),
              ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChanged(
                AttendanceStatus.other,
                remark: controller.text.trim(),
              );
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
              const TabBar(
                tabs: [
                  Tab(text: '总群汇报'),
                  Tab(text: '学委汇报'),
                ],
              ),
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
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Toast.show(context, '已复制$label');
            },
            icon: const Icon(Icons.copy),
            label: Text('复制$label'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
      ],
    );
  }
}
