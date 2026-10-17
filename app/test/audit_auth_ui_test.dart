import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lesson_search/core/network/error_message.dart';
import 'package:lesson_search/features/auth/presentation/login_page.dart';
import 'package:lesson_search/features/auth/presentation/register_page.dart';
import 'package:lesson_search/shared/design_system/theme.dart';
import 'package:lesson_search/shared/design_system/widgets/app_button.dart';
import 'package:lesson_search/shared/design_system/widgets/segmented_control.dart';
import 'package:lesson_search/shared/providers.dart';

Future<void> pumpAuth(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWith(
          (ref) => throw StateError('No API in auth layout test'),
        ),
        databaseProvider.overrideWith(
          (ref) => throw StateError('No database in auth layout test'),
        ),
        syncServiceProvider.overrideWith(
          (ref) => throw StateError('No sync in auth layout test'),
        ),
      ],
      child: MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectCodeControlsVisible(WidgetTester tester) async {
  final input = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == '6 位数字',
  );
  final send = find.widgetWithText(AppButton, '发送');
  await tester.ensureVisible(input);
  await tester.pumpAndSettle();
  expect(input.hitTestable(), findsOneWidget);
  expect(
    tester.renderObject<RenderParagraph>(find.text('6 位数字')).didExceedMaxLines,
    isFalse,
  );
  final inputRect = tester.getRect(input);
  await tester.ensureVisible(send);
  await tester.pumpAndSettle();
  expect(send.hitTestable(), findsOneWidget);
  expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
  // Narrow / large-text forms put sending below the full-width input.
  expect(tester.getSize(input).width, greaterThan(250));
  expect(
    tester.getRect(send).top,
    greaterThanOrEqualTo(tester.getRect(input).bottom),
  );
  expect(inputRect.width, tester.getSize(input).width);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    '320dp large-text login shows both modes, complete code hint and registration link',
    (tester) async {
      await pumpAuth(tester, '/login');
      final modes = find.byType(AppSegmentedControl<bool>);
      for (final label in ['验证码', '密码']) {
        final text = find.descendant(of: modes, matching: find.text(label));
        expect(text.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(modes).contains(tester.getRect(text).topLeft),
          isTrue,
        );
        expect(
          tester.getRect(modes).contains(tester.getRect(text).bottomRight),
          isTrue,
        );
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
      }
      await tester.enterText(
        find.byType(TextField).first,
        'guest@example.test',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '6 位数字',
        ),
        '123456',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectCodeControlsVisible(tester);

      await tester.ensureVisible(modes);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: modes, matching: find.text('密码')));
      await tester.pumpAndSettle();
      final password = find.byWidgetPredicate(
        (w) => w is TextField && w.obscureText,
      );
      await tester.ensureVisible(password);
      await tester.enterText(password, 'test-password');
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'guest@example.test',
      );

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(modes);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: modes, matching: find.text('验证码')));
      await tester.pumpAndSettle();
      final code = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '6 位数字',
      );
      expect(tester.widget<TextField>(code).controller!.text, '123456');
      await expectCodeControlsVisible(tester);
      await tester.ensureVisible(find.text('去注册'));
      await tester.pumpAndSettle();
      expect(find.text('去注册').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('去注册'));
      await tester.pumpAndSettle();
      expect(find.byType(RegisterPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '320dp large-text registration keeps fields, send and login link usable',
    (tester) async {
      await pumpAuth(tester, '/register');
      await expectCodeControlsVisible(tester);
      final invitation = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '请输入邀请码',
      );
      await tester.ensureVisible(invitation);
      await tester.enterText(invitation, 'layout-only');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final register = find.widgetWithText(AppButton, '注册');
      await tester.ensureVisible(register);
      await tester.pumpAndSettle();
      expect(register.hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('去登录'));
      await tester.pumpAndSettle();
      expect(find.text('去登录').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('去登录'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  group('F24 pure response error extraction', () {
    test(
      'HTML is suppressed rather than indexed or exposed as user detail',
      () {
        expect(responseErrorDetail('<html>Bad Gateway</html>'), '');
        expect(responseErrorDetail('  <!DOCTYPE html><title>502</title>'), '');
      },
    );
    test('plain String detail is trimmed', () {
      expect(responseErrorDetail('  验证码无效  '), '验证码无效');
    });
    test('Map detail, message and msg keys are safely extracted', () {
      expect(responseErrorDetail({'detail': '密码错误'}), '密码错误');
      expect(responseErrorDetail({'message': '请求被拒绝'}), '请求被拒绝');
      expect(responseErrorDetail({'msg': '字段必填'}), '字段必填');
      expect(
        responseErrorDetail({
          'detail': {'msg': '嵌套错误'},
        }),
        '嵌套错误',
      );
    });
    test(
      'List responses combine structured errors and ignore unsupported entries',
      () {
        expect(
          responseErrorDetail([
            {'msg': '字段必填'},
            '格式错误',
            null,
            42,
            '<html>proxy</html>',
          ]),
          '字段必填；格式错误',
        );
        expect(
          responseErrorDetail({
            'detail': [
              {'msg': '格式不正确'},
            ],
          }),
          '格式不正确',
        );
      },
    );
    test('null and unsupported scalar responses have no detail', () {
      for (final data in [null, 1, false, const Object(), <String, Object>{}]) {
        expect(responseErrorDetail(data), '');
      }
    });
    test(
      'Dio HTML failure falls back safely while validation List keeps detail',
      () {
        DioException failure(dynamic data, int status) {
          final request = RequestOptions(path: '/auth/send-code');
          return DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: request,
              statusCode: status,
              data: data,
            ),
          );
        }

        expect(
          dioErrorMessage(failure('<html>502</html>', 502)),
          '服务暂时不可用，请稍后重试',
        );
        expect(
          dioErrorMessage(
            failure([
              {'msg': '邮箱格式错误'},
            ], 422),
          ),
          '邮箱格式错误',
        );
      },
    );
  });
}
