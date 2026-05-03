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

      if (mounted) {
        Toast.show(context, '密码设置成功');
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      final detail = e.response?.data['detail'] ?? '';
      if (mounted) {
        Toast.show(context, detail.isNotEmpty ? detail : '设置失败');
      }
    } on Exception {
      if (mounted) {
        Toast.show(context, '网络错误，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
