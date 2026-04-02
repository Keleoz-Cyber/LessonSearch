import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    // P4: 点名流程路由
    // GoRoute(path: '/roll-call/select', ...),
    // GoRoute(path: '/roll-call/execute', ...),

    // P5: 记名流程路由
    // GoRoute(path: '/name-check/select', ...),
    // GoRoute(path: '/name-check/execute', ...),
    // GoRoute(path: '/name-check/confirm', ...),
    // GoRoute(path: '/name-check/text-gen', ...),

    // P7: 查课记录路由
    // GoRoute(path: '/records', ...),
    // GoRoute(path: '/records/:id', ...),
  ],
);
