import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/entry_card.dart';
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
                FeatureCard(
                  icon: Icons.send_outlined,
                  title: '名单提交',
                  subtitle: isAdmin ? '查看提交状态、审核记录' : '提交本周记名任务供审核',
                  color: Colors.green,
                  onTap: () => context.push('/extension/submission'),
                ),
                const SizedBox(height: 16),
                FeatureCard(
                  icon: Icons.summarize_outlined,
                  title: '周名单汇总',
                  subtitle: isAdmin ? '审核提交、导出汇总表' : '查看已发布的周汇总名单',
                  color: Colors.orange,
                  onTap: () => context.push('/extension/weekly-summary'),
                ),
                const SizedBox(height: 16),
                FeatureCard(
                  icon: Icons.file_upload_outlined,
                  title: '任务导入',
                  subtitle: '手动导入考勤任务',
                  color: Colors.blue,
                  onTap: () => Toast.show(context, '敬请期待'),
                ),
                const SizedBox(height: 16),
                FeatureCard(
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
