import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/announcement/announcement_service.dart';
import '../../../core/resume/task_resume_checker.dart';
import '../../../core/sync/sync_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/entry_card.dart';

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
    final syncState = ref.watch(syncStateProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => context.push('/debug/sync'),
          child: const Text('查课'),
        ),
        centerTitle: true,
        actions: [
          // 同步状态指示器（带数量徽章）
          pendingCount.when(
            data: (count) {
              if (count == 0 && syncState != SyncState.syncing) {
                return const SizedBox.shrink();
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (syncState == SyncState.syncing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (syncState == SyncState.error)
                    IconButton(
                      icon: const Icon(Icons.sync_problem, color: Colors.red),
                      tooltip: '同步异常，点击重试',
                      onPressed: () => ref.read(syncServiceProvider).syncNow(),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: '同步记录',
                      onPressed: () => ref.read(syncServiceProvider).syncNow(),
                    ),
                  // 数量徽章
                  if (count > 0 && syncState != SyncState.syncing)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 未同步记录警告卡片
                _buildSyncWarningCard(),
                EntryCard(
                  icon: Icons.record_voice_over,
                  title: '点名',
                  subtitle: '按学号依次点名',
                  color: Colors.blue,
                  onTap: () => _checkLoginAndNavigate('/roll-call/select'),
                ),
                const SizedBox(height: 16),
                EntryCard(
                  icon: Icons.checklist,
                  title: '记名',
                  subtitle: '逐人记录考勤状态',
                  color: Colors.green,
                  onTap: () => _checkLoginAndNavigate('/name-check/select'),
                ),
                const SizedBox(height: 16),
                EntryCard(
                  icon: Icons.history,
                  title: '查课记录',
                  subtitle: '查看与编辑历史记录',
                  color: Colors.orange,
                  onTap: () => _checkLoginAndNavigate('/records'),
                ),
                const SizedBox(height: 16),
                EntryCard(
                  icon: Icons.extension,
                  title: '扩展功能',
                  subtitle: '导入、提交、汇总、排行',
                  color: Colors.purple,
                  onTap: () => _checkLoginAndNavigate('/extension'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 未同步记录警告卡片
  Widget _buildSyncWarningCard() {
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final syncState = ref.watch(syncStateProvider);

    return pendingCount.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();

        // 如果有未同步记录且当前不在同步中，自动触发同步
        if (syncState != SyncState.syncing && count > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(syncServiceProvider).syncNow();
          });
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: syncState == SyncState.syncing
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: syncState == SyncState.syncing
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: syncState == SyncState.syncing
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      syncState == SyncState.syncing
                          ? Icons.sync
                          : Icons.warning_amber,
                      color: syncState == SyncState.syncing
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syncState == SyncState.syncing
                              ? '正在自动同步 $count 条记录...'
                              : '有 $count 条记录未同步',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          syncState == SyncState.syncing
                              ? '同步期间请避免编辑记录或提交审核，以防数据冲突'
                              : '系统将在后台自动同步，请避免重复编辑同一条记录',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
