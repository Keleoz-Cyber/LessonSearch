import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class ExtensionPage extends ConsumerWidget {
  const ExtensionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text('扩展功能')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeatureCard(
                  icon: Icons.send_outlined,
                  title: '名单提交',
                  subtitle: isAdmin ? '查看提交状态、审核记录' : '提交本周记名任务供审核',
                  color: Colors.green,
                  onTap: () => context.push('/extension/submission'),
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.summarize_outlined,
                  title: '周名单汇总',
                  subtitle: isAdmin ? '审核提交、导出汇总表' : '查看已发布的周汇总名单',
                  color: Colors.orange,
                  onTap: () => context.push('/extension/weekly-summary'),
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.file_upload_outlined,
                  title: '任务导入',
                  subtitle: '手动导入考勤任务',
                  color: Colors.blue,
                  onTap: () => Toast.show(context, '敬请期待'),
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.leaderboard_outlined,
                  title: '排行榜',
                  subtitle: '查看考勤统计排行',
                  color: Colors.purple,
                  onTap: () => Toast.show(context, '敬请期待'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
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
