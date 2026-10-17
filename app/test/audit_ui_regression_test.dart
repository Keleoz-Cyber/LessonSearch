import 'dart:async';
import 'package:lesson_search/features/extension/data/submission_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lesson_search/core/sync/sync_service.dart';
import 'package:lesson_search/core/network/api_client.dart';
import 'package:lesson_search/features/extension/presentation/submission_search_page.dart';
import 'package:lesson_search/features/attendance/application/name_check_notifier.dart';
import 'package:lesson_search/features/attendance/data/attendance_repository.dart';
import 'package:lesson_search/features/attendance/domain/models.dart';
import 'package:lesson_search/features/attendance/domain/text_template.dart';
import 'package:lesson_search/features/attendance/presentation/confirmation/confirmation_page.dart';
import 'package:lesson_search/features/attendance/presentation/name_check/name_check_page.dart';
import 'package:lesson_search/features/attendance/presentation/text_generation/text_gen_page.dart';
import 'package:lesson_search/features/extension/presentation/submission_page.dart';
import 'package:lesson_search/features/home/presentation/home_page.dart';
import 'package:lesson_search/features/student/data/student_repository.dart';
import 'package:lesson_search/shared/design_system/colors.dart';
import 'package:lesson_search/shared/design_system/theme.dart';
import 'package:lesson_search/shared/design_system/widgets/app_button.dart';
import 'package:lesson_search/shared/design_system/widgets/segmented_control.dart';
import 'package:lesson_search/shared/design_system/widgets/skeleton.dart';
import 'package:lesson_search/shared/design_system/widgets/status_pill.dart';
import 'package:lesson_search/shared/design_system/widgets/sync_status_banner.dart';
import 'package:lesson_search/shared/providers.dart';
import 'package:lesson_search/shared/widgets/loading_overlay.dart';

class _SearchService extends SubmissionService {
  _SearchService() : super(ApiClient(baseUrl: 'http://127.0.0.1:1'));
  final requests = <(Map<String, dynamic>, Completer<Map<String, dynamic>>)>[];
  @override
  Future<List<dynamic>> getSemesters() async => [
    {'id': 1, 'semester_name': '当前测试学期', 'start_date': '2026-09-07'},
    {'id': 2, 'semester_name': '上一测试学期', 'start_date': '2026-02-23'},
  ];
  @override
  Future<Map<String, dynamic>> adminSearchSubmissions({
    int page = 1,
    int pageSize = 20,
    String? status,
    int? weekNumber,
    int? semesterId,
    int? userId,
    String? startDate,
    String? endDate,
    String? keyword,
  }) {
    final future = Completer<Map<String, dynamic>>();
    requests.add((
      {'page': page, 'status': status, 'semester_id': semesterId},
      future,
    ));
    return future.future;
  }
}

class _Attendance implements AttendanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Students implements StudentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SeededNameCheck extends NameCheckNotifier {
  _SeededNameCheck(NameCheckState seed) : super(_Attendance(), _Students()) {
    state = seed;
  }
  int completions = 0;
  int marks = 0;
  @override
  Future<void> completeWorkflow() async {
    completions++;
  }

  @override
  Future<void> startNameCheck({
    required List<int> classIds,
    required int gradeId,
    required int majorId,
    int? userId,
  }) async {}
  @override
  Future<void> markStudentById(
    int classId,
    int studentId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    marks++;
  }
}

class _Sync implements SyncService {
  @override
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  @override
  Stream<SyncCompleteEvent> get onSyncComplete => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _class = ClassInfo(
  id: 1,
  gradeId: 1,
  majorId: 1,
  classCode: 'A',
  displayName: '示例班',
);
const _present = StudentWithStatus(
  student: StudentInfo(id: 1, name: '到课同学', studentNo: '001', classId: 1),
  status: AttendanceStatus.present,
);
const _late = StudentWithStatus(
  student: StudentInfo(id: 2, name: '迟到同学', studentNo: '002', classId: 1),
  status: AttendanceStatus.late_,
);

Widget _wrap(Widget child, {bool reduced = false, double scale = 1}) =>
    MaterialApp(
      theme: buildLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _SearchService searchApi() => _SearchService();

  void respond(
    (Map<String, dynamic>, Completer<Map<String, dynamic>>) request, {
    String? name,
  }) {
    request.$2.complete({
      'items': [
        if (name != null)
          {
            'id': 1,
            'user_name': name,
            'status': 'approved',
            'submitted_at': '2026-10-17T10:00:00',
            'week_number': 6,
          },
      ],
      'total': name == null ? 0 : 1,
    });
  }

  testWidgets('F25 search completion after disposal does not access State', (
    tester,
  ) async {
    final server = searchApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [submissionSearchServiceProvider.overrideWithValue(server)],
        child: _wrap(const SubmissionSearchPage()),
      ),
    );
    await tester.pump();
    expect(server.requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    respond(server.requests.single);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'F27 a new filter replaces in-flight search, stale response is ignored',
    (tester) async {
      final server = searchApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            submissionSearchServiceProvider.overrideWithValue(server),
          ],
          child: _wrap(const SubmissionSearchPage()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('全部状态'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('已通过'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(server.requests, hasLength(2));
      expect(server.requests.last.$1['status'], 'approved');
      respond(server.requests.last, name: '新条件结果');
      await tester.pump(const Duration(milliseconds: 50));
      respond(server.requests.first, name: '旧条件结果');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('新条件结果'), findsOneWidget);
      expect(find.text('旧条件结果'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('F28 cancelling week picker preserves the existing filter', (
    tester,
  ) async {
    final server = searchApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [submissionSearchServiceProvider.overrideWithValue(server)],
        child: _wrap(const SubmissionSearchPage()),
      ),
    );
    await tester.pump();
    respond(server.requests.single);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部周次'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '12');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    respond(server.requests.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 12 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('第 12 周'), findsOneWidget);
    expect(server.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F07 historical search sends an explicit semester identity', (
    tester,
  ) async {
    final server = searchApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [submissionSearchServiceProvider.overrideWithValue(server)],
        child: _wrap(const SubmissionSearchPage()),
      ),
    );
    await tester.pump();
    respond(server.requests.single);
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前学期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上一测试学期'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(server.requests.last.$1['semester_id'], 2);
    respond(server.requests.last);
    await tester.pumpAndSettle();
    expect(find.text('上一测试学期'), findsOneWidget);
  });

  testWidgets('F30 long other remarks wrap outside the short status label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const remark = '这是很长的其他状态说明需要完整保留并且不得挤掉姓名和学号';
    final now = DateTime(2026, 10, 17);
    final notifier = _SeededNameCheck(
      NameCheckState(
        task: AttendanceTask(
          id: 'test',
          type: TaskType.nameCheck,
          createdAt: now,
          updatedAt: now,
        ),
        classes: const [_class],
        studentsByClass: const {
          1: [
            StudentWithStatus(
              student: StudentInfo(
                id: 1,
                name: '测试同学',
                studentNo: '001',
                classId: 1,
              ),
              status: AttendanceStatus.other,
              remark: remark,
            ),
          ],
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nameCheckProvider.overrideWith((ref) => notifier)],
        child: _wrap(const ConfirmationPage(), scale: 2),
      ),
    );
    expect(find.text('测试同学'), findsOneWidget);
    expect(find.text(remark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('F11 clean attendance alone gets the full-attendance shorthand', () {
    expect(
      generateGroupReport(const [
        ClassStats(
          className: 'A',
          total: 1,
          present: 1,
          absent: 0,
          late_: 0,
          leave: 0,
          other: 0,
          absentStudents: [],
          lateStudents: [],
          leaveStudents: [],
          otherStudents: [],
        ),
      ], 'date'),
      contains('全勤'),
    );
  });

  testWidgets('F11 late-only class keeps late name in the real report', (
    tester,
  ) async {
    final notifier = _SeededNameCheck(
      const NameCheckState(
        classes: [_class],
        studentsByClass: {
          1: [_present, _late],
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nameCheckProvider.overrideWith((ref) => notifier)],
        child: _wrap(const TextGenPage(taskId: 'test')),
      ),
    );
    await tester.tap(find.text('总群汇报'));
    await tester.pumpAndSettle();
    final reports = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data ?? '')
        .join('\n');
    expect(reports, contains('应到 2 人，实到 2 人'));
    expect(reports, contains('迟到同学'));
    expect(reports, isNot(contains('全勤')));
  });

  testWidgets('F12 finishing a local report never requests the online week', (
    tester,
  ) async {
    var weekRequests = 0;
    final notifier = _SeededNameCheck(const NameCheckState());
    final router = GoRouter(
      initialLocation: '/text',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('已回首页')),
        GoRoute(
          path: '/text',
          builder: (_, _) => const TextGenPage(taskId: 'test'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nameCheckProvider.overrideWith((ref) => notifier),
          currentWeekProvider.overrideWith((ref) async {
            weekRequests++;
            throw StateError('offline');
          }),
        ],
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('已回首页'), findsOneWidget);
    expect(notifier.completions, 1);
    expect(weekRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F13 finishing locks marking and back actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = _SeededNameCheck(
      const NameCheckState(
        classes: [_class],
        studentsByClass: {
          1: [_present],
        },
        isFinishing: true,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          nameCheckProvider.overrideWith((ref) => notifier),
          hasSyncFailedProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: _wrap(
          const NameCheckPage(
            classIds: [1],
            classNames: ['示例班'],
            gradeId: 1,
            majorId: 1,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('正在保存名单...'), findsOneWidget);
    await tester.tap(find.text('到课'), warnIfMissed: false);
    await tester.pump();
    expect(notifier.marks, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('退出记名'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('F26 cancelling loading cannot pop the page on completion', (
    tester,
  ) async {
    LoadingDialogHandle? handle;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                handle = LoadingDialogHandle.show(context);
              },
              child: const Text('加载'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('加载'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handle!.close(), isFalse);
    expect(find.text('加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 375.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('F29 home fits width $width at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, width == 800 ? 375 : 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'dismissed_announcement_version': 999999,
        });
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              syncServiceProvider.overrideWithValue(_Sync()),
              syncIssueCountProvider.overrideWith((ref) => Stream.value(0)),
              resumableTasksProvider.overrideWith((ref) => Stream.value([])),
              hasSyncFailedProvider.overrideWith((ref) => Stream.value(false)),
            ],
            child: _wrap(const HomePage(), scale: scale),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'F29 F31 long class segments are scrollable and have 48dp targets',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 280,
            child: AppSegmentedControl<int>(
              items: const [
                AppSegmentedItem(value: 1, label: '计算机科学与技术一班'),
                AppSegmentedItem(value: 2, label: '计算机科学与技术二班'),
                AppSegmentedItem(value: 3, label: '计算机科学与技术三班'),
              ],
              value: 1,
              onChanged: (_) {},
            ),
          ),
          scale: 2,
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      for (final ink in find.byType(InkWell).evaluate()) {
        expect(
          (ink.renderObject as RenderBox).size.height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in AppButtonSize.values) {
    testWidgets(
      'F29 F31 button $size has accessible target and flexible label',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox(
                width: 140,
                child: AppButton.primary(
                  label: '开始记名并保存记录',
                  onPressed: () {},
                  size: size,
                  leadingIcon: Icons.check,
                ),
              ),
            ),
            scale: 2,
          ),
        );
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('F31 status text and gradient foreground retain 4.5 contrast', (
    tester,
  ) async {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    for (final dark in [false, true]) {
      for (final variant in StatusPillVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? buildDarkTheme() : buildLightTheme(),
            home: Scaffold(
              body: StatusPill(label: '状态', variant: variant),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text('状态'));
        final box = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusPill),
            matching: find.byType(Container),
          ),
        );
        final bg = (box.decoration as BoxDecoration).color!;
        final surface = dark
            ? AppColors.dark.bgSurface
            : AppColors.light.bgSurface;
        expect(
          contrast(text.style!.color!, Color.alphaBlend(bg, surface)),
          greaterThanOrEqualTo(4.5),
        );
      }
      final colors = dark ? AppColors.dark : AppColors.light;
      expect(
        contrast(colors.onBrand, colors.brandGradientFrom),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(colors.onBrand, colors.brandGradientTo),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('F32 reduced motion freezes skeleton and sync rotation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          children: [
            SkeletonBox(width: 200, height: 24),
            SyncStatusBanner(state: SyncBannerState.syncing, title: '同步中'),
          ],
        ),
        reduced: true,
      ),
    );
    final box = find.descendant(
      of: find.byType(SkeletonBox),
      matching: find.byType(Container),
    );
    final before =
        (tester.widget<Container>(box).decoration as BoxDecoration).gradient;
    final turn = tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(SyncStatusBanner),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      (tester.widget<Container>(box).decoration as BoxDecoration).gradient,
      before,
    );
    expect(
      tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byType(SyncStatusBanner),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value,
      turn,
    );
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
