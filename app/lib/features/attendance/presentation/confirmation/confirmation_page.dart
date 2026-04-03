import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/providers.dart';
import '../../../attendance/application/name_check_notifier.dart';
import '../../../attendance/domain/models.dart';

/// 记名确认页：展示异常名单（未到/请假/其他），按班级分组
class ConfirmationPage extends ConsumerWidget {
  const ConfirmationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nameCheckProvider);
    final task = state.task;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('确认名单')),
        body: const Center(child: Text('无任务数据')),
      );
    }

    // 收集异常记录，按班级分组
    final abnormalByClass = <String, List<_AbnormalEntry>>{};
    for (final cls in state.classes) {
      final students = state.studentsByClass[cls.id] ?? [];
      final abnormals = students
          .where((s) => s.status != AttendanceStatus.present && s.status != AttendanceStatus.pending)
          .map((s) => _AbnormalEntry(
                name: s.student.name,
                studentNo: s.student.studentNo,
                status: s.status,
                remark: s.remark,
              ))
          .toList();
      if (abnormals.isNotEmpty) {
        abnormalByClass[cls.displayName] = abnormals;
      }
    }

    final totalStudents = state.totalStudents;
    final abnormalCount = abnormalByClass.values.fold<int>(0, (sum, list) => sum + list.length);

    return Scaffold(
      appBar: AppBar(title: const Text('确认名单')),
      body: Column(
        children: [
          // 统计摘要
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Text(
              '共 $totalStudents 人，异常 $abnormalCount 人'
              '${abnormalCount == 0 ? "（全部到齐）" : ""}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),

          // 异常名单
          Expanded(
            child: abnormalByClass.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('全部到齐，没有异常记录'),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: abnormalByClass.entries.map((entry) {
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
                          ...entry.value.map((e) => _AbnormalRow(entry: e)),
                          const Divider(),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          // 底部按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(nameCheckProvider.notifier).resumeEditing();
                      context.pop();
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('重新编辑'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      context.push('/text-gen', extra: {'taskId': task.id});
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('确认名单'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AbnormalEntry {
  final String name;
  final String studentNo;
  final AttendanceStatus status;
  final String? remark;

  const _AbnormalEntry({
    required this.name,
    required this.studentNo,
    required this.status,
    this.remark,
  });

  String get statusLabel => switch (status) {
        AttendanceStatus.absent => '缺勤',
        AttendanceStatus.late_ => '迟到',
        AttendanceStatus.leave => '请假',
        AttendanceStatus.other => remark ?? '其他',
        _ => '',
      };

  Color get statusColor => switch (status) {
        AttendanceStatus.absent => Colors.red,
        AttendanceStatus.late_ => Colors.amber.shade700,
        AttendanceStatus.leave => Colors.orange,
        AttendanceStatus.other => Colors.purple,
        _ => Colors.grey,
      };
}

class _AbnormalRow extends StatelessWidget {
  final _AbnormalEntry entry;

  const _AbnormalRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(entry.name)),
          Expanded(flex: 3, child: Text(entry.studentNo, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: entry.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.statusLabel,
              style: TextStyle(color: entry.statusColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
