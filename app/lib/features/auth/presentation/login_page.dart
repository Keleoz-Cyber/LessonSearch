import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  bool _isLoading = false;
  bool _isSendingCode = false;
  int _countdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
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
        hint = e.response?.data['detail'] ?? '发送失败';
      }
      Toast.show(context, hint);
    } on Exception {
      Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      Toast.show(context, '请填写所有字段');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final authService = ref.read(authServiceProvider);

      final response = await apiClient.login(email: email, code: code);

      await authService.saveAuth(
        token: response['token'],
        userId: response['user']['id'],
        email: response['user']['email'],
        nickname: response['user']['nickname'],
      );

      // 刷新登录状态
      ref.invalidate(authServiceProvider);
      ref.invalidate(isLoggedInProvider);
      ref.invalidate(userEmailProvider);
      ref.invalidate(apiClientProvider);

      if (mounted) {
        context.pop();
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('使用邮箱验证码登录', style: Theme.of(context).textTheme.titleMedium),
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
                SizedBox(
                  width: 100,
                  height: 48,
                  child: FilledButton(
                    onPressed: _countdown > 0 || _isSendingCode
                        ? null
                        : _sendCode,
                    child: Text(_countdown > 0 ? '${_countdown}s' : '发送'),
                  ),
                ),
              ],
            ),
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
