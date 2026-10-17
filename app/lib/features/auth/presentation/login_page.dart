import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/design_system/widgets/segmented_control.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';
import '../../../core/auth/account_session.dart';
import '../../../core/network/error_message.dart';

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
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_isSendingCode || _countdown > 0) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Toast.show(context, '请输入正确的邮箱地址');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.sendVerificationCode(email);
      if (!mounted) return;
      Toast.show(context, '验证码已发送');
      setState(() => _countdown = 60);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _countdown <= 1) {
          timer.cancel();
          if (mounted) setState(() => _countdown = 0);
        } else {
          setState(() => _countdown--);
        }
      });
    } on DioException catch (e) {
      if (mounted) {
        Toast.show(context, dioErrorMessage(e, fallback: '发送失败，请稍后重试'));
      }
    } on Exception {
      if (mounted) Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
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
      final detail = dioErrorMessage(e, fallback: '登录失败');
      String hint = '登录失败';
      if (detail.contains('账户不存在')) {
        hint = '账户不存在，请先注册';
      } else if (detail.contains('验证码')) {
        hint = '验证码无效或已过期';
      } else if (detail.isNotEmpty) {
        hint = detail;
      }
      if (mounted) Toast.show(context, hint);
    } on AccountSessionException catch (e) {
      if (mounted) Toast.show(context, e.message);
    } on Exception {
      if (mounted) Toast.show(context, '网络错误，请稍后重试');
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
      final detail = dioErrorMessage(e, fallback: '登录失败');
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
      if (mounted) Toast.show(context, hint);
    } on AccountSessionException catch (e) {
      if (mounted) Toast.show(context, e.message);
    } on Exception {
      if (mounted) Toast.show(context, '网络错误，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> response) async {
    if (!mounted) return;
    await finalizeAuthentication(ref, response);
    if (mounted) {
      final realName = response['user']['real_name'];
      if (realName == null || realName.toString().trim().isEmpty) {
        context.go('/real-name');
      } else {
        context.go('/');
      }
    }
  }

  Widget _buildCodeInput() {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final input = TextField(
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
          style: AppTextStyles.body.copyWith(color: c.textPrimary),
        );
        final send = AppButton.secondary(
          label: _countdown > 0 ? '${_countdown}s' : '发送',
          onPressed: _countdown > 0 || _isSendingCode ? null : _sendCode,
          loading: _isSendingCode,
          size: AppButtonSize.lg,
          fullWidth: stacked,
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: AppSpacing.md),
              send,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: input),
            const SizedBox(width: AppSpacing.md),
            send,
          ],
        );
      },
    );
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
                AppSegmentedItem(value: false, label: '验证码'),
                AppSegmentedItem(value: true, label: '密码'),
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
              _buildCodeInput(),
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

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  '没有账户？',
                  style: AppTextStyles.body.copyWith(color: c.textSecondary),
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
