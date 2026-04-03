import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../features/attendance/presentation/selection/selection_page.dart';
import '../../features/attendance/presentation/roll_call/roll_call_page.dart';
import '../../features/debug/sync_test_page.dart';
import '../../features/home/presentation/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // 点名选择页
    GoRoute(
      path: '/roll-call/select',
      name: 'roll-call-select',
      builder: (context, state) =>
          const SelectionPage(taskType: TaskType.rollCall),
    ),

    // 点名执行页
    GoRoute(
      path: '/roll-call/execute',
      name: 'roll-call-execute',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return RollCallPage(
          classId: extra['classId'] as int,
          gradeId: extra['gradeId'] as int,
          majorId: extra['majorId'] as int,
          className: extra['className'] as String,
        );
      },
    ),

    // 联调测试页
    GoRoute(
      path: '/debug/sync',
      name: 'sync-test',
      builder: (context, state) => const SyncTestPage(),
    ),

    // P7: 记名流程路由（待实现）
    // GoRoute(path: '/name-check/select', ...),
    // GoRoute(path: '/name-check/execute', ...),

    // P9: 查课记录路由（待实现）
    // GoRoute(path: '/records', ...),
  ],
);
