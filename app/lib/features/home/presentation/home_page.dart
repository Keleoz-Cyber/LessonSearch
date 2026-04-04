import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/announcement/announcement_service.dart';
import '../../../core/resume/task_resume_checker.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AnnouncementService.checkAndShow(context);
      if (!mounted) return;
      await TaskResumeChecker.check(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => context.push('/debug/sync'),
          child: const Text('查课'),
        ),
        centerTitle: true,
        actions: [
          // 同步状态指示器
          if (syncState == SyncState.syncing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (syncState == SyncState.error)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.sync_problem, color: Colors.red),
                tooltip: '同步异常，点击重试',
                onPressed: () => ref.read(syncServiceProvider).syncNow(),
              ),
            ),
          // 设置
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EntryCard(
                  icon: Icons.record_voice_over,
                  title: '点名',
                  subtitle: '按学号依次点名',
                  color: Colors.blue,
                  onTap: () => context.push('/roll-call/select'),
                ),
                const SizedBox(height: 16),
                _EntryCard(
                  icon: Icons.checklist,
                  title: '记名',
                  subtitle: '逐人记录考勤状态',
                  color: Colors.green,
                  onTap: () => context.push('/name-check/select'),
                ),
                const SizedBox(height: 16),
                _EntryCard(
                  icon: Icons.history,
                  title: '查课记录',
                  subtitle: '查看与编辑历史记录',
                  color: Colors.orange,
                  onTap: () => context.push('/records'),
                ),
                const SizedBox(height: 16),
                _EntryCard(
                  icon: Icons.extension,
                  title: '扩展功能',
                  subtitle: '导入、提交、汇总、排行',
                  color: Colors.purple,
                  onTap: () => context.push('/extension'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
