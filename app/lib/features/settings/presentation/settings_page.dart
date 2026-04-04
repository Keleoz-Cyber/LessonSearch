import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/announcement/announcement_config.dart';
import '../../../shared/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // --- 应用信息 ---
          const _SectionHeader(title: '应用信息'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('查课 App'),
            subtitle: Text('课堂考勤查课工具'),
          ),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('版本号'),
            subtitle: Text('0.2.5'),
          ),

          const Divider(),

          // --- 功能 ---
          const _SectionHeader(title: '功能'),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('查看公告'),
            subtitle: const Text('查看最新公告信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAnnouncement(context),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('当前已是最新版本'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
            },
          ),

          const Divider(),

          // --- 显示 ---
          const _SectionHeader(title: '显示'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('暗色模式'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),

          const Divider(),

          // --- 关于 ---
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('开发者与致谢'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '暗色模式';
    }
  }

  void _showThemeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              label: '跟随系统',
              selected: currentMode == ThemeMode.system,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            _ThemeOption(
              label: '亮色模式',
              selected: currentMode == ThemeMode.light,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            _ThemeOption(
              label: '暗色模式',
              selected: currentMode == ThemeMode.dark,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncement(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(announcementTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                announcementContent.trim(),
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  updateNotes.trim(),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ============================================================
// 关于页 — 开发者与致谢
// ============================================================
// 编辑下面的内容修改开发者信息和致谢名单

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者与致谢')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- 开发者信息（编辑这里）---
          const _InfoSection(
            title: '开发者',
            children: [
              _PersonTile(name: 'keleoz', role: '开发者', icon: Icons.code),
              // 添加更多开发者：
              // _PersonTile(name: '张三', role: 'UI 设计', icon: Icons.design_services),
            ],
          ),

          const SizedBox(height: 24),

          // --- 致谢名单（编辑这里）---
          const _InfoSection(
            title: '致谢',
            children: [
              _PersonTile(name: '暂未设置', role: '暂未设置', icon: Icons.smart_toy),
              // 添加更多致谢：
              // _PersonTile(name: '李四', role: '测试支持', icon: Icons.bug_report),
            ],
          ),

          const SizedBox(height: 24),

          // --- 技术栈 ---
          const _InfoSection(
            title: '技术栈',
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.phone_android, size: 20),
                title: Text('Flutter + Riverpod + Drift'),
                subtitle: Text('客户端'),
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.cloud, size: 20),
                title: Text('FastAPI + MySQL'),
                subtitle: Text('服务端'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          Center(
            child: Text(
              '查课 App v0.2.5',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name;
  final String role;
  final IconData icon;

  const _PersonTile({
    required this.name,
    required this.role,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, size: 20),
      ),
      title: Text(name),
      subtitle: Text(role),
    );
  }
}
