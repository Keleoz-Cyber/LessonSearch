import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/providers.dart';
import '../../../../shared/widgets/toast.dart';
import '../../../attendance/domain/models.dart';
import '../../../attendance/domain/text_template.dart';

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
  String _committeeReport = '';
  bool _generated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateTexts();
  }

  @override
  void dispose() {
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
      _committeeReport = generateCommitteeReport(classStatsList, date);
      _generated = true;
    });
  }

  void _copyAndOpenApp(String text, bool isWechat) async {
    Clipboard.setData(ClipboardData(text: text));
    Toast.show(context, '已复制到剪贴板');

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('生成汇报文本'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '总群汇报'),
              Tab(text: '学委汇报'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTextView(_groupReport, isWechat: true),
            _buildTextView(_committeeReport, isWechat: false),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _finish,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('完成'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextView(String text, {required bool isWechat}) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.icon(
            onPressed: () => _copyAndOpenApp(text, isWechat),
            icon: Icon(isWechat ? Icons.wechat : Icons.message),
            label: Text(isWechat ? '复制并打开微信' : '复制并打开QQ'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: isWechat ? Colors.green : Colors.blue,
            ),
          ),
        ),
      ],
    );
  }
}
