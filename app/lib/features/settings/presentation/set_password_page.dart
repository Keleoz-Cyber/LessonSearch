import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final hasPasswordAsync = ref.watch(hasPasswordProvider);

    return Scaffold(
      appBar: AppBar(
        title: hasPasswordAsync.when(
          data: (hasPassword) => Text(hasPassword ? '修改密码' : '设置密码'),
          loading: () => const Text('设置密码'),
          error: (_, __) => const Text('设置密码'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '新密码',
                hintText: '至少6位',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                labelText: '确认密码',
                hintText: '再次输入密码',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
              obscureText: _obscureConfirm,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
