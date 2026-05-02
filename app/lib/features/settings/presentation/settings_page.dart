import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/announcement/announcement_config.dart';
import '../../../core/logger/logger_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import 'markdown_document_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final userEmail = ref.watch(userEmailProvider);
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader(title: '账户'),
          ListTile(
            leading: Icon(isLoggedIn ? Icons.account_circle : Icons.login),
            title: Text(isLoggedIn ? userEmail ?? '已登录' : '登录'),
            subtitle: Text(isLoggedIn ? '点击退出登录' : '使用邮箱验证码登录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleAuth(context, ref, isLoggedIn),
          ),

          const Divider(),

          const _SectionHeader(title: '同步'),
          ListTile(
            leading: Icon(
              syncState == SyncState.syncing
                  ? Icons.sync
                  : syncState == SyncState.error
                      ? Icons.sync_problem
                      : Icons.sync_outlined,
              color: syncState == SyncState.error
                  ? Colors.orange
                  : syncState == SyncState.syncing
                      ? Theme.of(context).colorScheme.primary
                      : null,
            ),
            title: const Text('手动同步'),
            subtitle: Text(
              syncState == SyncState.syncing
                  ? '正在同步中...'
                  : syncState == SyncState.error
                      ? '上次同步失败，点击重试'
                      : '点击立即同步数据',
            ),
            trailing: syncState == SyncState.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: syncState == SyncState.syncing
                ? null
                : () => _syncNow(context, ref),
          ),

          const Divider(),

          const _SectionHeader(title: '统计'),
          FutureBuilder(
            future: ref.read(databaseProvider).getStatistics(),
            builder: (context, snapshot) {
              final stats = snapshot.data ??
                  {
                    'total_tasks': 0,
                    'completed_tasks': 0,
                    'abandoned_tasks': 0,
                    'in_progress_tasks': 0,
                    'total_records': 0,
                    'pending_sync': 0,
                  };
              return Column(
                children: [
                  _StatTile(
                    icon: Icons.task_alt,
                    title: '查课任务',
                    subtitle:
                        '${stats['completed_tasks']} 个完成 · ${stats['in_progress_tasks']} 个进行中 · ${stats['abandoned_tasks']} 个放弃',
                    value: '',
                  ),
                  _StatTile(
                    icon: Icons.people_outline,
                    title: '考勤记录',
                    value: '${stats['total_records']} 条',
                  ),
                  _StatTile(
                    icon: Icons.sync_alt,
                    title: '待同步',
                    value: '${stats['pending_sync']}',
                    color: stats['pending_sync']! > 0 ? Colors.orange : null,
                  ),
                ],
              );
            },
          ),

          const Divider(),

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
            subtitle: const Text('当前版本: 0.6.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _checkUpdate(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text('网络诊断'),
            subtitle: const Text('测试与服务器的连通性'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/debug/sync'),
          ),

          const Divider(),

          const _SectionHeader(title: '显示'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题'),
            subtitle: Text(_themeModeLabel(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),

          const Divider(),

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

          const _SectionHeader(title: '数据'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清理缓存'),
            subtitle: const Text('清除日志和临时数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showClearCacheDialog(context),
          ),

          const Divider(),

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
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUserAgreement(context),
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
    final hasUnsynced = unsyncedCount > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasUnsynced) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '无法退出登录',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '有 $unsyncedCount 条数据未同步到服务器。退出登录会清空本地所有数据，导致未同步记录永久丢失。',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('请先完成同步后再退出登录。'),
            ] else ...[
              const Text('确定要退出登录吗？'),
              const SizedBox(height: 12),
              const Text('退出后本地数据将被清空。'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          if (hasUnsynced)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx, false);
                // 立即同步
                await _syncNow(context, ref);
              },
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('立即同步'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出'),
            ),
        ],
      ),
    );

    // 有未同步数据时，不允许退出
    if (hasUnsynced) return;

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

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text(
          '确定要清理缓存吗？\n\n'
          '这将清除：\n'
          '• 调试日志记录\n'
          '• 临时缓存数据\n\n'
          '不会影响您的查课记录和登录状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await LoggerService.clear();
      Toast.show(context, '缓存已清理');
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    try {
      Toast.show(context, '开始同步...');
      await ref.read(syncServiceProvider).syncNow();
      if (context.mounted) {
        Toast.show(context, '同步完成');
      }
    } catch (e) {
      if (context.mounted) {
        Toast.show(context, '同步失败: $e');
      }
    }
  }

  void _openPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MarkdownDocumentPage(
          title: '隐私政策',
          assetPath: 'assets/privacy_policy.md',
        ),
      ),
    );
  }

  void _openUserAgreement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MarkdownDocumentPage(
          title: '用户协议',
          assetPath: 'assets/user_agreement.md',
        ),
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
          child: MarkdownBody(
            data: announcementContent.trim(),
            styleSheet: MarkdownStyleSheet(
              h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              p: const TextStyle(height: 1.6),
              listBullet: const TextStyle(height: 1.6),
            ),
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
          child: SizedBox(
            width: double.maxFinite,
            child: MarkdownBody(
              data: updateNotes.trim(),
              styleSheet: MarkdownStyleSheet(
                h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                p: const TextStyle(fontSize: 13, height: 1.5),
                listBullet: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
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
      LoggerService.sync('开始检查更新...');
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.checkUpdate();
      LoggerService.sync('响应: $response');

      final latestVersion = response['version'] as String;
      final downloadUrl = response['download_url'] as String;
      final releaseNotes = response['release_notes'] as String;

      const currentVersion = '0.6.0';
      LoggerService.sync('当前版本: $currentVersion, 最新版本: $latestVersion');

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
      LoggerService.error('检查更新错误: $e');
      LoggerService.error('堆栈: $stackTrace');
      if (context.mounted) {
        Toast.show(context, '检查更新失败: $e');
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? color;

  const _StatTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: value != null && value!.isNotEmpty
          ? Text(
              value!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
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
// 关于页 — 开发者与致谢（彩蛋：点击开发者7次触发爱心雨）
// ============================================================

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  int _tapCount = 0;
  bool _showEasterEgg = false;
  final List<_HeartAnimation> _heartAnimations = [];

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

  static const _titles = [
    '代码魔法师',
    '熬夜冠军',
    'Bug终结者',
    '键盘战士',
    '咖啡依赖症患者',
    'Git push大师',
    '改需求抵抗者',
  ];

  void _triggerEasterEgg() {
    if (_showEasterEgg) return;

    setState(() => _showEasterEgg = true);

    ref.read(feedbackServiceProvider).heavyFeedback();

    _startHeartRain();
  }

  void _startHeartRain() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    for (int i = 0; i < 30; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (!mounted) return;

        final heart = _HeartAnimation(
          startX: (screenWidth * 0.1) + (i % 6) * (screenWidth * 0.15),
          endY: screenHeight + 40,
          color: [
            Colors.red,
            Colors.pink,
            Colors.orange,
            Colors.purple,
            Colors.deepOrange,
          ][i % 5],
          size: 24.0 + (i % 4) * 8,
          delay: i * 80,
        );

        setState(() => _heartAnimations.add(heart));

        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) setState(() => _heartAnimations.remove(heart));
        });
      });
    }
  }

  void _onDeveloperTap() {
    _tapCount++;
    if (_tapCount >= 7) {
      _triggerEasterEgg();
      _tapCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('致谢')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _InfoSection(
                title: '开发者',
                children: [
                  InkWell(
                    onTap: _onDeveloperTap,
                    borderRadius: BorderRadius.circular(8),
                    child: _PersonTile(
                      name: 'keleoz',
                      role: _showEasterEgg
                          ? _titles[DateTime.now().second % _titles.length]
                          : '开发者',
                      icon: _showEasterEgg ? Icons.auto_awesome : Icons.code,
                      showGlow: _showEasterEgg,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

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

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '致谢名单',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5),
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

              const SizedBox(height: 24),

              Builder(
                builder: (context) => _InfoSection(
                  title: '法律信息',
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                      title: const Text('隐私政策'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarkdownDocumentPage(
                            title: '隐私政策',
                            assetPath: 'assets/privacy_policy.md',
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 20),
                      title: const Text('用户协议'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarkdownDocumentPage(
                            title: '用户协议',
                            assetPath: 'assets/user_agreement.md',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  '考勤助手 v0.6.0',
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
        ),

        ..._heartAnimations.map(
          (heart) => Positioned(
            left: heart.startX,
            top: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: heart.endY),
              duration: const Duration(milliseconds: 2500),
              curve: Curves.easeIn,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: Icon(
                    Icons.favorite,
                    color: heart.color,
                    size: heart.size,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HeartAnimation {
  final double startX;
  final double endY;
  final Color color;
  final double size;
  final int delay;

  _HeartAnimation({
    required this.startX,
    required this.endY,
    required this.color,
    required this.size,
    required this.delay,
  });
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
  final bool showGlow;

  const _PersonTile({
    required this.name,
    required this.role,
    required this.icon,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        decoration: showGlow
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, size: 20),
        ),
      ),
      title: Text(
        name,
        style: showGlow
            ? TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)
            : null,
      ),
      subtitle: Text(role),
    );
  }
}
