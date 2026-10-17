import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lesson_search/core/sync/sync_service.dart';
import 'package:lesson_search/features/attendance/data/attendance_repository.dart';
import 'package:lesson_search/features/home/presentation/home_page.dart';
import 'package:lesson_search/shared/design_system/theme.dart';
import 'package:lesson_search/shared/providers.dart';

class _GuestAttendanceRepository implements AttendanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Guest home must not query attendance storage');
}

void main() {
  testWidgets('Guest home renders entries and protects attendance actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dismissed_announcement_version': 999999,
    });
    final prefs = await SharedPreferences.getInstance();

    // AnnouncementService uses a static Dio rather than apiClientProvider.
    // Reject its client creation before any actual socket or file I/O.
    await HttpOverrides.runZoned(
      () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              syncStateProvider.overrideWithValue(SyncState.idle),
              syncIssueCountProvider.overrideWith((ref) => Stream.value(0)),
              hasSyncFailedProvider.overrideWith((ref) => Stream.value(false)),
              resumableTasksProvider.overrideWith((ref) => Stream.value([])),
              attendanceRepositoryProvider.overrideWithValue(
                _GuestAttendanceRepository(),
              ),
              databaseProvider.overrideWith(
                (ref) => throw StateError('No database in guest smoke'),
              ),
              apiClientProvider.overrideWith(
                (ref) => throw StateError('No API in guest smoke'),
              ),
              syncServiceProvider.overrideWith(
                (ref) => throw StateError('No sync in guest smoke'),
              ),
            ],
            child: MaterialApp(
              theme: buildLightTheme(),
              home: const HomePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('考勤助手'), findsOneWidget);
        expect(find.text('开始记名'), findsOneWidget);
        expect(find.text('点名'), findsOneWidget);
        expect(find.text('查课记录'), findsOneWidget);
        expect(find.text('继续未完成任务'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('开始记名'));
        await tester.pumpAndSettle();
        expect(find.text('请先登录'), findsOneWidget);
        expect(find.text('去登录'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
      createHttpClient: (_) => throw StateError('HTTP disabled by guest smoke'),
    );
  });
}
