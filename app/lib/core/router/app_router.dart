import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../features/attendance/presentation/selection/selection_page.dart';
import '../../features/attendance/presentation/roll_call/roll_call_page.dart';
import '../../features/attendance/presentation/name_check/name_check_page.dart';
import '../../features/attendance/presentation/confirmation/confirmation_page.dart';
import '../../features/attendance/presentation/text_generation/text_gen_page.dart';
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

    // 点名
    GoRoute(
      path: '/roll-call/select',
      name: 'roll-call-select',
      builder: (context, state) =>
          const SelectionPage(taskType: TaskType.rollCall),
    ),
    GoRoute(
      path: '/roll-call/execute',
      name: 'roll-call-execute',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return RollCallPage(
          classIds: (extra['classIds'] as List).cast<int>(),
          classNames: (extra['classNames'] as List).cast<String>(),
          gradeId: extra['gradeId'] as int,
          majorId: extra['majorId'] as int,
        );
      },
    ),

    // 记名
    GoRoute(
      path: '/name-check/select',
      name: 'name-check-select',
      builder: (context, state) =>
          const SelectionPage(taskType: TaskType.nameCheck),
    ),
    GoRoute(
      path: '/name-check/execute',
      name: 'name-check-execute',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return NameCheckPage(
          classIds: (extra['classIds'] as List).cast<int>(),
          classNames: (extra['classNames'] as List).cast<String>(),
          gradeId: extra['gradeId'] as int,
          majorId: extra['majorId'] as int,
        );
      },
    ),

    // 确认页
    GoRoute(
      path: '/confirmation',
      name: 'confirmation',
      builder: (context, state) => const ConfirmationPage(),
    ),

    // 文本生成
    GoRoute(
      path: '/text-gen',
      name: 'text-gen',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return TextGenPage(taskId: extra['taskId'] as String);
      },
    ),

    // 联调测试
    GoRoute(
      path: '/debug/sync',
      name: 'sync-test',
      builder: (context, state) => const SyncTestPage(),
    ),
  ],
);
