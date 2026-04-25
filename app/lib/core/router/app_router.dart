import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/domain/models.dart';
import '../../features/attendance/presentation/selection/selection_page.dart';
import '../../features/attendance/presentation/roll_call/roll_call_page.dart';
import '../../features/attendance/presentation/name_check/name_check_page.dart';
import '../../features/attendance/presentation/confirmation/confirmation_page.dart';
import '../../features/attendance/presentation/text_generation/text_gen_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/real_name_page.dart';
import '../../features/extension/presentation/extension_page.dart';
import '../../features/extension/presentation/submission_page.dart';
import '../../features/extension/presentation/weekly_summary_page.dart';
import '../../features/ranking/presentation/ranking_page.dart';
import '../../features/records/presentation/records_list_page.dart';
import '../../features/records/presentation/record_detail_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/debug/debug_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../shared/providers.dart';

final _routerKey = GlobalKey<NavigatorState>();

String? _redirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context);
  final auth = container.read(authServiceProvider);
  final isLoggedIn = auth.isLoggedIn;
  final hasRealName = auth.hasRealName;
  final goingToRealName = state.matchedLocation == '/real-name';

  if (isLoggedIn && !hasRealName && !goingToRealName) {
    return '/real-name';
  }

  if (isLoggedIn && hasRealName && goingToRealName) {
    return '/';
  }

  final protectedRoutes = [
    '/roll-call',
    '/name-check',
    '/confirmation',
    '/text-gen',
    '/records',
    '/extension',
    '/settings',
  ];

  final needsLogin = protectedRoutes.any(
    (r) => state.matchedLocation.startsWith(r),
  );

  if (needsLogin && !isLoggedIn) {
    return '/login';
  }

  return null;
}

final appRouter = GoRouter(
  navigatorKey: _routerKey,
  initialLocation: '/',
  redirect: _redirect,
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),

    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),

    GoRoute(
      path: '/real-name',
      name: 'real-name',
      builder: (context, state) => const RealNamePage(),
    ),

    GoRoute(
      path: '/extension',
      name: 'extension',
      builder: (context, state) => const ExtensionPage(),
    ),
    GoRoute(
      path: '/extension/submission',
      name: 'submission',
      builder: (context, state) => const SubmissionPage(),
    ),
    GoRoute(
      path: '/extension/weekly-summary',
      name: 'weekly-summary',
      builder: (context, state) => const WeeklySummaryPage(),
    ),
    GoRoute(
      path: '/extension/ranking',
      name: 'ranking',
      builder: (context, state) => const RankingPage(),
    ),

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
          resumeTaskId: extra['resumeTaskId'] as String?,
        );
      },
    ),

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
          resumeTaskId: extra['resumeTaskId'] as String?,
        );
      },
    ),

    GoRoute(
      path: '/confirmation',
      name: 'confirmation',
      builder: (context, state) => const ConfirmationPage(),
    ),

    GoRoute(
      path: '/text-gen',
      name: 'text-gen',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return TextGenPage(taskId: extra['taskId'] as String);
      },
    ),

    GoRoute(
      path: '/records',
      name: 'records',
      builder: (context, state) => const RecordsListPage(),
    ),
    GoRoute(
      path: '/records/:id',
      name: 'record-detail',
      builder: (context, state) =>
          RecordDetailPage(taskId: state.pathParameters['id']!),
    ),

    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),

    GoRoute(
      path: '/debug/sync',
      name: 'sync-test',
      builder: (context, state) => const DebugPage(),
    ),
  ],
);
