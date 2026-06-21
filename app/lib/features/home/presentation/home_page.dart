import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/announcement/announcement_service.dart';
import '../../../core/resume/task_resume_checker.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/app_card.dart';
import '../../../shared/design_system/widgets/sync_status_banner.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

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
      await _checkTokenValidity();
      if (!mounted) return;
      _checkRealName();
      if (!mounted) return;
      await AnnouncementService.checkAndShow(context);
      if (!mounted) return;
      await TaskResumeChecker.check(context, ref);
    });
  }

  void _checkRealName() {
    final auth = ref.read(authServiceProvider);
    if (auth.isLoggedIn && !auth.hasRealName) {
      context.go('/real-name');
    }
  }

  Future<void> _checkTokenValidity() async {
    final auth = ref.read(authServiceProvider);

    // 之前有登录记录但 Token 没了（过期或被清除），强制跳转登录
    if (auth.token == null && auth.userId != null) {
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('登录状态已过期，需要重新认证。本地数据已保留，登录后可继续同步。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!auth.isLoggedIn || auth.token == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.get('/auth/me');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          // 只清除 token，保留 userId 等用户信息
          // 避免清空本地数据库，让用户重新登录后继续同步
          await auth.clearTokenOnly();
          ref.invalidate(authServiceProvider);
          ref.invalidate(isLoggedInProvider);
          context.go('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录状态已过期，需要重新认证。本地数据已保留，登录后可继续同步。'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (_) {
      // 忽略其他网络错误（网络不通时不应该登出）
    }
  }

  void _checkLoginAndNavigate(String route) {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (isLoggedIn) {
      context.push(route);
    } else {
      _showLoginRequiredDialog();
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('请先登录'),
        content: const Text('为保护学生隐私数据安全，使用查课功能前需要先登录账户。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/login');
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHero()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList.list(
                children: [
                  _buildSyncWarningCard(),
                  _buildPrimaryActions(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSecondaryActions(),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final c = context.colors;
    final syncState = ref.watch(syncStateProvider);
    final issueCount = ref.watch(syncIssueCountProvider);
    final count = issueCount.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onLongPress: () => context.push('/debug/sync'),
                  child: Text(
                    '考勤助手',
                    style: AppTextStyles.display.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '高效记录课堂考勤',
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          _buildSyncIndicator(syncState, count),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: c.textSecondary),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(SyncState state, int count) {
    final c = context.colors;
    if (count == 0 && state != SyncState.syncing) return const SizedBox.shrink();

    IconData icon;
    Color color;
    if (state == SyncState.syncing) {
      icon = Icons.sync;
      color = c.stateInfo;
    } else if (state == SyncState.error) {
      icon = Icons.sync_problem;
      color = c.stateDanger;
    } else {
      icon = Icons.sync;
      color = c.stateWarning;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: state == SyncState.syncing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              : Icon(icon, color: color),
          tooltip: state == SyncState.error ? '同步异常，点击重试' : '同步记录',
          onPressed: () => ref.read(syncServiceProvider).syncNow(),
        ),
        if (count > 0 && state != SyncState.syncing)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: c.stateDanger,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: context.colors.onBrand,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: SizedBox(
            height: 88,
            child: AppButton.gradient(
              label: '开始记名',
              onPressed: () => _checkLoginAndNavigate('/name-check/select'),
              leadingIcon: Icons.checklist,
              fullWidth: true,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 88,
            child: AppButton.secondary(
              label: '点名',
              onPressed: () => _checkLoginAndNavigate('/roll-call/select'),
              leadingIcon: Icons.record_voice_over,
              fullWidth: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions() {
    final auth = ref.watch(authServiceProvider);
    final isAdmin = auth.isAdmin;

    final entries = <_SecondaryEntry>[
      _SecondaryEntry(
        icon: Icons.history,
        title: '查课记录',
        subtitle: '查看与编辑历史',
        onTap: () => _checkLoginAndNavigate('/records'),
      ),
      _SecondaryEntry(
        icon: Icons.send_outlined,
        title: '名单提交',
        subtitle: isAdmin ? '查看与审核' : '提交本周记名',
        onTap: () => _checkLoginAndNavigate('/extension/submission'),
      ),
      _SecondaryEntry(
        icon: Icons.summarize_outlined,
        title: '周名单汇总',
        subtitle: isAdmin ? '审核与导出' : '查看本周汇总',
        onTap: () => _checkLoginAndNavigate('/extension/weekly-summary'),
      ),
      _SecondaryEntry(
        icon: Icons.leaderboard_outlined,
        title: '排行榜',
        subtitle: '考勤统计排名',
        onTap: () => _checkLoginAndNavigate('/extension/ranking'),
      ),
      if (isAdmin)
        _SecondaryEntry(
          icon: Icons.search_outlined,
          title: '提交记录查询',
          subtitle: '查询历史提交',
          onTap: () => _checkLoginAndNavigate('/extension/submission-search'),
        ),
      _SecondaryEntry(
        icon: Icons.more_horiz,
        title: '更多功能',
        subtitle: '即将推出',
        onTap: () => Toast.show(context, '敬请期待'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        for (final e in entries)
          _buildEntryCard(
            icon: e.icon,
            title: e.title,
            subtitle: e.subtitle,
            onTap: e.onTap,
          ),
      ],
    );
  }

  Widget _buildEntryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.normal),
            ),
            child: Icon(icon, size: 18, color: c.brandPrimary),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.h3.copyWith(color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.sm.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncWarningCard() {
    final issueCount = ref.watch(syncIssueCountProvider);
    final syncState = ref.watch(syncStateProvider);
    final hasSyncFailed = ref.watch(hasSyncFailedProvider);
    final isSyncFailed = hasSyncFailed.valueOrNull ?? false;

    return issueCount.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();

        if (syncState != SyncState.syncing && count > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(syncServiceProvider).syncNow();
          });
        }

        final state = isSyncFailed
            ? SyncBannerState.failed
            : syncState == SyncState.syncing
                ? SyncBannerState.syncing
                : SyncBannerState.unknown;

        final title = isSyncFailed
            ? '$count 条数据同步失败'
            : syncState == SyncState.syncing
                ? '正在自动同步 $count 条记录'
                : '$count 条记录待同步';

        final desc = isSyncFailed
            ? '请先处理后再继续编辑或提交'
            : syncState == SyncState.syncing
                ? '请避免同时编辑或提交，防止冲突'
                : '系统将在后台自动同步';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: SyncStatusBanner(
            state: state,
            title: title,
            description: desc,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SecondaryEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SecondaryEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
