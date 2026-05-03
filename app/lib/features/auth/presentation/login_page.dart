import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logger/logger_service.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingCode = false;
  int _countdown = 0;
  bool _usePassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Toast.show(context, '请输入正确的邮箱地址');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      LoggerService.network('发送验证码到: $email');
      await apiClient.sendVerificationCode(email);

      Toast.show(context, '验证码已发送');

      setState(() => _countdown = 60);
      while (_countdown > 0) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) break;
        setState(() => _countdown--);
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      String hint = '发送失败';
      if (status == 429) {
        hint = '请求过于频繁，请稍后再试';
      } else if (status == 500) {
        hint = '服务器错误，请检查SMTP配置';
      } else {
        final detail = e.response?.data['detail'];
        if (detail is List) {
          hint = detail.isNotEmpty ? detail.first.toString() : '发送失败';
        } else {
          hint = detail?.toString() ?? '发送失败';
        }
      }
      Toast.show(context, hint);
    } on Exception {
      Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _login() async {
    if (_usePassword) {
      await _passwordLogin();
    } else {
      await _codeLogin();
    }
  }

  Future<void> _codeLogin() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      Toast.show(context, '请填写所有字段');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.login(email: email, code: code);

      await _handleLoginSuccess(response);
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? '';
      String hint = '登录失败';
      if (detail.contains('账户不存在')) {
        hint = '账户不存在，请先注册';
      } else if (detail.contains('验证码')) {
        hint = '验证码无效或已过期';
      } else if (detail.isNotEmpty) {
        hint = detail;
      }
      Toast.show(context, hint);
    } on Exception {
      Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _passwordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      Toast.show(context, '请填写所有字段');
      return;
    }

    if (password.length < 6) {
      Toast.show(context, '密码至少需要 6 位');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.passwordLogin(
        email: email,
        password: password,
      );

      await _handleLoginSuccess(response);
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? '';
      String hint = '登录失败';
      if (detail.contains('账户不存在')) {
        hint = '账户不存在，请先注册';
      } else if (detail.contains('尚未设置密码')) {
        hint = '该账号尚未设置密码，请先使用验证码登录';
      } else if (detail.contains('密码错误')) {
        hint = '密码错误';
      } else if (detail.isNotEmpty) {
        hint = detail;
      }
      Toast.show(context, hint);
    } on Exception {
      Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> response) async {
    final authService = ref.read(authServiceProvider);

    await authService.saveAuth(
      token: response['token'],
      userId: response['user']['id'],
      email: response['user']['email'],
      nickname: response['user']['nickname'],
      realName: response['user']['real_name'],
      role: response['user']['role'],
    );

    ref.invalidate(authServiceProvider);
    ref.invalidate(isLoggedInProvider);
    ref.invalidate(userEmailProvider);
    ref.invalidate(apiClientProvider);
    // 重置认证过期状态
    ref.read(authExpiredProvider.notifier).state = false;

    if (mounted) {
      // 登录成功后，重置因 401 标记为 failed 的同步项，让它们能继续同步
      final localDS = ref.read(attendanceLocalDSProvider);
      final resetCount = await localDS.resetAuthFailedSyncItems();
      if (resetCount > 0) {
        LoggerService.sync('登录成功: 重置 $resetCount 条因认证过期失败的同步项');
      }

      // 触发同步，继续之前失败的同步
      ref.read(syncServiceProvider).syncNow();

      final realName = response['user']['real_name'];
      if (realName == null || realName.toString().trim().isEmpty) {
        context.go('/real-name');
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 登录方式切换
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('验证码登录'),
                  icon: Icon(Icons.message_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('密码登录'),
                  icon: Icon(Icons.password_outlined),
                ),
              ],
              selected: {_usePassword},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _usePassword = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱',
                hintText: '请输入邮箱地址',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            if (!_usePassword) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '6位数字',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FilledButton(
                      onPressed: _countdown > 0 || _isSendingCode
                          ? null
                          : _sendCode,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(80, 48),
                      ),
                      child: Text(_countdown > 0 ? '${_countdown}s' : '发送'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '密码',
                  hintText: '至少6位',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '没有账户？',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('去注册'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
