import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _invitationCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingCode = false;
  int _countdown = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _invitationCodeController.dispose();
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

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final invitationCode = _invitationCodeController.text.trim();

    if (email.isEmpty || code.isEmpty || invitationCode.isEmpty) {
      Toast.show(context, '请填写所有字段');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final authService = ref.read(authServiceProvider);

      final response = await apiClient.register(
        email: email,
        code: code,
        invitationCode: invitationCode,
      );

      await authService.saveAuth(
        token: response['token'],
        userId: response['user']['id'],
        email: response['user']['email'],
        nickname: response['user']['nickname'],
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? '';
      String hint = '注册失败';
      if (detail.contains('邀请码无效')) {
        hint = '邀请码无效';
      } else if (detail.contains('已被使用')) {
        hint = '邀请码已被使用';
      } else if (detail.contains('已注册')) {
        hint = '该邮箱已注册，请直接登录';
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注册成功'),
        content: const Text(
          '首次登录后，新创建的查课记录将仅属于当前账户。\n\n历史本地数据将继续在此设备上展示，但不会同步到服务器。',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('创建新账户', style: Theme.of(context).textTheme.titleMedium),
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
            const SizedBox(height: 16),

            TextField(
              controller: _invitationCodeController,
              decoration: const InputDecoration(
                labelText: '邀请码',
                hintText: '请输入邀请码',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('注册'),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '已有账户？',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('去登录'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
