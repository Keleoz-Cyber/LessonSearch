import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/logger/logger_service.dart';
import 'shared/design_system/theme.dart';
import 'shared/providers.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription? _syncSubscription;
  bool _isStartupSync = false; // 标记是否是启动同步

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenAuthState();
      _listenSyncComplete();
      _checkPendingSyncOnStartup();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// 监听同步完成，仅在启动同步时显示提示（避免后台定时同步频繁弹窗）
  void _listenSyncComplete() {
    final syncService = ref.read(syncServiceProvider);
    _syncSubscription = syncService.onSyncComplete.listen((event) {
      if (_isStartupSync && event.success > 0 && event.failed == 0) {
        _isStartupSync = false; // 重置标志位
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已同步 ${event.success} 条记录到服务器'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _listenAuthState() {
    ref.listenManual(isLoggedInProvider, (prev, next) {
      if (prev == true && next == false) {
        final router = GoRouter.of(context);
        final current = router.routerDelegate.currentConfiguration.uri.toString();
        if (current != '/login' && current != '/register') {
          router.go('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录已过期，本地数据已保留，请重新登录'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  /// 启动时检查是否有未同步或同步失败的记录，并自动同步
  Future<void> _checkPendingSyncOnStartup() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      final localDS = ref.read(attendanceLocalDSProvider);
      
      // 检查待同步和已失败的记录
      final pendingItems = await localDS.getPendingSyncItems();
      final failedItems = await localDS.getFailedSyncItems();
      final totalNeedSync = pendingItems.length + failedItems.length;
      
      if (totalNeedSync > 0) {
        // 如果有失败记录，先重置为待同步状态
        if (failedItems.isNotEmpty) {
          await localDS.retryAllFailed();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('检测到 ${failedItems.length} 条记录同步失败，已重置并重新同步...'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '查看',
                  onPressed: () {
                    context.push('/debug');
                  },
                ),
              ),
            );
          }
          LoggerService.sync('启动检查: 发现 ${failedItems.length} 条失败记录，已重置');
        } else {
          // 只有待同步记录
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('检测到 ${pendingItems.length} 条记录未同步，正在自动同步...'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '查看',
                  onPressed: () {
                    context.push('/debug');
                  },
                ),
              ),
            );
          }
        }
        
        LoggerService.sync('启动检查: 共 $totalNeedSync 条记录需要同步，开始自动同步');
        
        // 标记为启动同步，完成后显示提示
        _isStartupSync = true;
        
        // 自动同步
        debugPrint('Starting startup sync...');
        final result = await syncService.syncNow();
        debugPrint('Startup sync done: success=${result.success}, failed=${result.failed}');
        
        if (result.failed == 0) {
          LoggerService.sync('启动同步完成: 成功=${result.success} 条');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('同步完成'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          LoggerService.sync('启动同步完成: 成功=${result.success} 失败=${result.failed} 条', isError: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('同步完成: ${result.success} 成功, ${result.failed} 失败'),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '查看',
                  onPressed: () {
                    context.push('/debug');
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      LoggerService.sync('启动同步检查失败: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '查课',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return child!;
      },
    );
  }
}
