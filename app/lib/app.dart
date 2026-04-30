import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/logger/logger_service.dart';
import 'core/sync/sync_success_animation.dart';
import 'shared/providers.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _showSyncSuccess = false;
  int _syncSuccessCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenAuthState();
      _checkPendingSyncOnStartup();
      _listenSyncResult();
    });
  }

  /// 监听同步结果，成功时显示动画
  void _listenSyncResult() {
    final syncService = ref.read(syncServiceProvider);
    syncService.lastResult.addListener(() {
      final result = syncService.lastResult.value;
      if (result != null && result.success > 0 && result.failed == 0) {
        if (mounted) {
          setState(() {
            _showSyncSuccess = true;
            _syncSuccessCount = result.success;
          });
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
      
      // 检查是否有待同步的记录
      final pendingItems = await localDS.getPendingSyncItems();
      
      if (pendingItems.isNotEmpty) {
        // 显示提示
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
        
        LoggerService.sync('启动检查: 发现 ${pendingItems.length} 条待同步记录，开始自动同步');
        
        // 自动同步
        final result = await syncService.syncNow();
        
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
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            // 同步成功动画覆盖层
            if (_showSyncSuccess)
              Positioned.fill(
                child: SyncSuccessOverlay(
                  successCount: _syncSuccessCount,
                  onDismiss: () {
                    setState(() {
                      _showSyncSuccess = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
