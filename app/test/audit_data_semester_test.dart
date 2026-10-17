import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lesson_search/core/network/api_client.dart';
import 'package:lesson_search/features/auth/data/auth_service.dart';
import 'package:lesson_search/features/extension/data/submission_service.dart';
import 'package:lesson_search/features/extension/presentation/weekly_summary_page.dart';
import 'package:lesson_search/shared/providers.dart';

class SemesterAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic data = <String, dynamic>{};
    if (options.path == '/week/semesters') {
      data = [
        {
          'id': 20,
          'semester_id': 20,
          'semester_name': 'New term',
          'start_date': '2026-09-07',
          'is_active': true,
        },
        {
          'id': 10,
          'semester_id': 10,
          'semester_name': 'Old term',
          'start_date': '2026-03-02',
          'is_active': false,
        },
      ];
    } else if (options.path == '/submissions/history') {
      data = [
        {'week_number': options.queryParameters['semester_id'] == 10 ? 8 : 2},
      ];
    } else if (options.path == '/submissions' ||
        options.path == '/submissions/pending' ||
        options.path == '/submissions/reviewed') {
      data = [];
    } else if (options.path.contains('week-summary')) {
      data = {'total_abnormal_students': 0, 'table_data': []};
    } else if (options.path.contains('export-status')) {
      data = {'is_published': true};
    } else if (options.path.contains('/export/')) {
      return ResponseBody.fromBytes([1, 2, 3], 200);
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'semester ID is preserved for every week/history/search/export request',
    () async {
      final api = ApiClient(baseUrl: 'https://unit.test/api');
      final adapter = SemesterAdapter();
      api.dio.httpClientAdapter = adapter;
      final service = SubmissionService(api);
      expect((await service.getSemesters()).length, 2);
      for (final term in [10, 20]) {
        final start = adapter.requests.length;
        await service.getMySubmissions(weekNumber: 1, semesterId: term);
        await service.getPendingSubmissions(weekNumber: 1, semesterId: term);
        await service.getReviewedSubmissions(weekNumber: 1, semesterId: term);
        await service.getExportStatus(1, semesterId: term);
        await service.getWeekSummary(1, semesterId: term);
        await service.getWeekSummaryDetail(1, semesterId: term);
        await service.getWeekSubmissionStatus(1, semesterId: term);
        await service.getHistoryWeeks(semesterId: term);
        await service.adminSearchSubmissions(weekNumber: 1, semesterId: term);
        await service.exportWeek(1, semesterId: term);
        expect(
          adapter.requests
              .skip(start)
              .every((r) => r.queryParameters['semester_id'] == term),
          true,
        );
      }
      await service.getWeekSummary(1);
      expect(
        adapter.requests.last.queryParameters.containsKey('semester_id'),
        false,
      );
      await service.createSubmission(weekNumber: 1, taskIds: ['test-task']);
      expect(
        (adapter.requests.last.data as Map).containsKey('semester_id'),
        false,
      );
    },
  );

  testWidgets(
    'history semester picker uses isolated week keys and selected ID for details',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService(await SharedPreferences.getInstance());
      await auth.saveAuth(
        token: 'unit-test',
        userId: 1,
        email: 'unit@example.test',
        realName: 'Unit',
      );
      final api = ApiClient(baseUrl: 'https://unit.test/api');
      final adapter = SemesterAdapter();
      api.dio.httpClientAdapter = adapter;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            submissionServiceProvider.overrideWithValue(SubmissionService(api)),
            currentWeekProvider.overrideWith(
              (ref) async => {
                'semester_id': 20,
                'week_number': 2,
                'semester_name': 'New term',
                'start_date': '2026-09-14',
                'end_date': '2026-09-20',
              },
            ),
            myDutyProvider.overrideWith((ref) async => {'has_duty': false}),
          ],
          child: const MaterialApp(home: WeeklySummaryPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史周次'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old term').last);
      await tester.pumpAndSettle();
      expect(find.text('第 8 周'), findsOneWidget);
      expect(
        adapter.requests
            .where((r) => r.path.endsWith('export-status/8'))
            .last
            .queryParameters['semester_id'],
        10,
      );
      await tester.tap(find.text('第 8 周'));
      await tester.pumpAndSettle();
      expect(
        adapter.requests
            .where((r) => r.path.endsWith('week-summary-detail/8'))
            .last
            .queryParameters['semester_id'],
        10,
      );
      expect(find.text('Old term · 第 8 周汇总'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
