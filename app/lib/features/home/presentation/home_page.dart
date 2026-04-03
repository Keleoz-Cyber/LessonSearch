import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('查课'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '联调测试',
            onPressed: () => context.push('/debug/sync'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EntryCard(
              icon: Icons.record_voice_over,
              title: '点名',
              subtitle: '随机点名查课',
              color: Colors.blue,
              onTap: () => context.push('/roll-call/select'),
            ),
            const SizedBox(height: 16),
            _EntryCard(
              icon: Icons.checklist,
              title: '记名',
              subtitle: '逐人记录考勤',
              color: Colors.green,
              onTap: () {
                // TODO P5: context.push('/name-check/select');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记名功能开发中')),
                );
              },
            ),
            const SizedBox(height: 16),
            _EntryCard(
              icon: Icons.history,
              title: '查课记录',
              subtitle: '查看历史记录',
              color: Colors.orange,
              onTap: () {
                // TODO P7: context.push('/records');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('查课记录功能开发中')),
                );
              },
            ),
          ],
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
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
