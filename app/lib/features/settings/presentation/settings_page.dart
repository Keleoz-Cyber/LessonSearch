import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/announcement/announcement_config.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final userEmail = ref.watch(userEmailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // --- 账户 ---
          const _SectionHeader(title: '账户'),
          ListTile(
            leading: Icon(isLoggedIn ? Icons.account_circle : Icons.login),
            title: Text(isLoggedIn ? userEmail ?? '已登录' : '登录'),
            subtitle: Text(isLoggedIn ? '点击退出登录' : '使用邮箱验证码登录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleAuth(context, ref, isLoggedIn),
          ),

          const Divider(),

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
            subtitle: Text('0.4.0'),
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
            leading: const Icon(Icons.history),
            title: const Text('更新日志'),
            subtitle: const Text('查看历史版本更新内容'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showUpdateNotes(context),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('检查是否有新版本'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkUpdate(context, ref),
          ),

          const Divider(),

          // --- 显示 ---
          const _SectionHeader(title: '显示'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),

          const Divider(),

          // --- 反馈 ---
          const _SectionHeader(title: '反馈'),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('振动反馈'),
            subtitle: const Text('操作时振动提示'),
            value: ref.watch(vibrationEnabledProvider),
            onChanged: (val) async {
              await ref.read(feedbackServiceProvider).setVibration(val);
              ref.invalidate(feedbackServiceProvider);
              ref.invalidate(vibrationEnabledProvider);
            },
          ),

          const Divider(),

          // --- 关于 ---
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('致谢'),
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

  void _handleAuth(BuildContext context, WidgetRef ref, bool isLoggedIn) {
    if (isLoggedIn) {
      _showLogoutDialog(context, ref);
    } else {
      context.push('/login');
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final unsyncedCount = await db.getUnsyncedCount();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要退出登录吗？'),
            const SizedBox(height: 12),
            if (unsyncedCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '有 $unsyncedCount 条数据未同步到服务器，退出后本地数据将被清空。',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text('退出后本地数据将被清空。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await db.clearUserData();
      await ref.read(authServiceProvider).clearAuth();
      ref.invalidate(authServiceProvider);
      ref.invalidate(isLoggedInProvider);
      ref.invalidate(userEmailProvider);
      ref.invalidate(apiClientProvider);
      Toast.show(context, '已退出登录');
    }
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
          child: Text(
            announcementContent.trim(),
            style: const TextStyle(height: 1.6),
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

  void _showUpdateNotes(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新日志'),
        content: SingleChildScrollView(
          child: Text(
            updateNotes.trim(),
            style: const TextStyle(fontSize: 13, height: 1.6),
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

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    try {
      debugPrint('[CheckUpdate] 开始检查更新...');
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.checkUpdate();
      debugPrint('[CheckUpdate] 响应: $response');

      final latestVersion = response['version'] as String;
      final downloadUrl = response['download_url'] as String;
      final releaseNotes = response['release_notes'] as String;

      const currentVersion = '0.4.0';
      debugPrint('[CheckUpdate] 当前版本: $currentVersion, 最新版本: $latestVersion');

      if (latestVersion == currentVersion) {
        if (context.mounted) {
          Toast.show(context, '当前已是最新版本');
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('发现新版本 v$latestVersion'),
            content: SingleChildScrollView(
              child: Text(
                releaseNotes,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后再说'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('立即更新'),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[CheckUpdate] 错误: $e');
      debugPrint('[CheckUpdate] 堆栈: $stackTrace');
      if (context.mounted) {
        Toast.show(context, '检查更新失败: $e');
      }
    }
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

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _ackList = [
    '清粥小菜(考研版)',
    '薯条',
    'Daewoo',
    '屿风',
    '冰水混合物',
    '苦情树下的苦命人',
    '心沦',
    '闲人、听曲',
    '秋ꄴ酿',
    '榆桉.',
    'Authentic',
    '#',
    '故事很久',
    '🍊',
    '白榆',
    '二二的亖',
    'e^(ix)=(cos x+isin x)',
    'AAA水电刘哥 金水路17号',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('致谢')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- 开发者信息 ---
          const _InfoSection(
            title: '开发者',
            children: [
              _PersonTile(name: 'keleoz', role: '开发者', icon: Icons.code),
            ],
          ),

          const SizedBox(height: 24),

          // --- 致谢 ---
          const _InfoSection(
            title: '致谢',
            children: [
              _PersonTile(
                name: 'Horldsense',
                role: '技术顾问',
                icon: Icons.lightbulb_outline,
              ),
              _PersonTile(
                name: 'Horldsense',
                role: 'iOS 适配',
                icon: Icons.phone_iphone,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- 致谢名单 ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '致谢名单',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '致学习部全体成员',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _ackList.map((name) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '排名不分先后',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
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
              '考勤助手 v0.4.0',
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
