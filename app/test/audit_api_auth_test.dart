import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lesson_search/core/network/api_client.dart';

class UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"detail":"Invalid credentials"}',
    401,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  final publicCalls = <String, Future<dynamic> Function(ApiClient)>{
    'code login': (api) => api.login(email: 'b@example.test', code: 'wrong'),
    'password login': (api) =>
        api.passwordLogin(email: 'b@example.test', password: 'wrong'),
    'registration': (api) => api.register(
      email: 'b@example.test',
      code: 'wrong',
      invitationCode: 'wrong',
    ),
    'send code': (api) => api.sendVerificationCode('b@example.test'),
  };
  for (final entry in publicCalls.entries) {
    test('public ${entry.key} 401 preserves existing A session', () async {
      var expired = 0;
      final api = ApiClient(
        baseUrl: 'https://unit.test/api',
        token: 'existing-a',
        onAuthExpired: () => expired++,
      );
      api.dio.httpClientAdapter = UnauthorizedAdapter();
      await expectLater(entry.value(api), throwsA(isA<DioException>()));
      expect(expired, 0);
      expect(api.token, 'existing-a');
    });
  }

  final protectedCalls = <String, Future<dynamic> Function(ApiClient)>{
    'current user': (api) => api.getCurrentUser(),
    'set password': (api) => api.setPassword('new-password'),
    'attendance task': (api) => api.getTask('test-task'),
  };
  for (final entry in protectedCalls.entries) {
    test('protected ${entry.key} 401 still expires session', () async {
      var expired = 0;
      final api = ApiClient(
        baseUrl: 'https://unit.test/api',
        token: 'expired-a',
        onAuthExpired: () => expired++,
      );
      api.dio.httpClientAdapter = UnauthorizedAdapter();
      await expectLater(entry.value(api), throwsA(isA<DioException>()));
      expect(expired, 1);
      expect(api.token, isNull);
    });
  }

  test(
    'credential route matching tolerates URL/query/slash but is not a prefix exemption',
    () async {
      var expired = 0;
      final api = ApiClient(
        baseUrl: 'https://unit.test/backend/v1/',
        token: 'existing-a',
        onAuthExpired: () => expired++,
      );
      api.dio.httpClientAdapter = UnauthorizedAdapter();
      for (final path in [
        '/auth/login/?source=unit',
        'https://unit.test/backend/v1/auth/password-login?source=unit',
      ]) {
        await expectLater(
          api.dio.post<dynamic>(path),
          throwsA(isA<DioException>()),
        );
        expect(expired, 0);
        expect(api.token, 'existing-a');
      }
      await expectLater(
        api.dio.get<dynamic>('/auth/login/protected'),
        throwsA(isA<DioException>()),
      );
      expect(expired, 1);
      expect(api.token, isNull);
    },
  );
}
