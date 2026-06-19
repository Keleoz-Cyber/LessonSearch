import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// 安全解析 DioException 中的错误信息
  /// 兼容 data 为 Map / String / List / null 等各种类型
  String _parseDioError(DioException e) {
    try {
      final data = e.response?.data;
      if (data == null) return '';
      if (data is String) return data;
      if (data is Map) {
        // 优先取 detail，其次 message
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.first.toString();
        }
        if (detail is Map) {
          return detail['msg']?.toString() ?? detail.toString();
        }
        final msg = data['message'];
        if (msg is String) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
        return data.toString();
      }
      if (data is List && data.isNotEmpty) return data.first.toString();
      return data.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      Toast.show(context, '请填写所有字段');
      return;
    }

    if (password.length < 6) {
      Toast.show(context, '密码至少需要 6 位');
      return;
    }

    if (password != confirm) {
      Toast.show(context, '两次输入的密码不一致');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.setPassword(password);

      ref.invalidate(hasPasswordProvider);

      if (mounted) {
        Toast.show(context, '密码设置成功');
        // 延迟 800ms 让用户看到提示，期间保持加载状态防止重复点击
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = _parseDioError(e);
        Toast.show(context, msg.isNotEmpty ? msg : '设置失败，请稍后重试');
      }
    } on Exception {
      if (mounted) {
        Toast.show(context, '网络错误，请稍后重试');
      }
    } finally {
      // 确保无论成功失败，loading 状态一定恢复
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPasswordAsync = ref.watch(hasPasswordProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: hasPasswordAsync.when(
          data: (hasPassword) => Text(hasPassword ? '修改密码' : '设置密码'),
          loading: () => const Text('设置密码'),
          error: (_, __) => const Text('设置密码'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '新密码',
                style: AppTextStyles.sm.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: '至少 6 位',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: c.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: c.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '确认密码',
                style: AppTextStyles.sm.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                hintText: '再次输入密码',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: c.textSecondary,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: c.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
              obscureText: _obscureConfirm,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xl2),
            AppButton.primary(
              label: '保存',
              onPressed: _isLoading ? null : _submit,
              loading: _isLoading,
              size: AppButtonSize.lg,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
