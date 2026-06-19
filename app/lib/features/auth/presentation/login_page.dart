import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logger/logger_service.dart';
import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/segmented_control.dart';
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

  /// 统一解析后端返回的 detail 字段，兼容 String / List / Map / null
  String _parseErrorDetail(dynamic detail) {
    if (detail == null) return '';
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) return detail.first.toString();
    if (detail is Map) return detail['msg']?.toString() ?? detail.toString();
    return detail.toString();
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
        final detail = _parseErrorDetail(e.response?.data['detail']);
        hint = detail.isNotEmpty ? detail : '发送失败';
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
      final detail = _parseErrorDetail(e.response?.data['detail']);
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
      final detail = _parseErrorDetail(e.response?.data['detail']);
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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: const Text('登录')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 登录方式切换
            AppSegmentedControl<bool>(
              items: const [
                AppSegmentedItem(value: false, label: '验证码登录'),
                AppSegmentedItem(value: true, label: '密码登录'),
              ],
              value: _usePassword,
              onChanged: (val) => setState(() => _usePassword = val),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 邮箱
            _FieldLabel(label: '邮箱'),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: '请输入邮箱地址',
                prefixIcon: Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: c.textSecondary,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (!_usePassword) ...[
              _FieldLabel(label: '验证码'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText: '6 位数字',
                        prefixIcon: Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: c.textSecondary,
                        ),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: AppTextStyles.body.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    height: 48,
                    child: AppButton.secondary(
                      label: _countdown > 0 ? '${_countdown}s' : '发送',
                      onPressed: _countdown > 0 || _isSendingCode
                          ? null
                          : _sendCode,
                      loading: _isSendingCode,
                      size: AppButtonSize.lg,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _FieldLabel(label: '密码'),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: '至少 6 位',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: c.textSecondary,
                  ),
                ),
                obscureText: true,
                style: AppTextStyles.body.copyWith(color: c.textPrimary),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            AppButton.gradient(
              label: '登录',
              onPressed: _isLoading ? null : _login,
              loading: _isLoading,
              size: AppButtonSize.lg,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '没有账户？',
                  style: AppTextStyles.body.copyWith(
                    color: c.textSecondary,
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTextStyles.sm.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
