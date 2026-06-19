import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/colors.dart';
import '../../../shared/design_system/tokens.dart';
import '../../../shared/design_system/typography.dart';
import '../../../shared/design_system/widgets/app_button.dart';
import '../../../shared/providers.dart';
import '../../../shared/widgets/toast.dart';

class RealNamePage extends ConsumerStatefulWidget {
  const RealNamePage({super.key});

  @override
  ConsumerState<RealNamePage> createState() => _RealNamePageState();
}

class _RealNamePageState extends ConsumerState<RealNamePage> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();

    if (name.isEmpty) {
      Toast.show(context, '请输入姓名');
      return;
    }

    if (name.length < 2 || name.length > 20) {
      Toast.show(context, '姓名长度应为 2-20 个字符');
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.put('/user/real-name', {'real_name': name});

      await ref.read(authServiceProvider).updateRealName(name);

      if (mounted) {
        Toast.show(context, '姓名已保存');
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: AppBar(
          title: const Text('完善信息'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xl2),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.brandSubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.badge_outlined,
                        size: 32,
                        color: c.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '请输入您的真实姓名',
                      style: AppTextStyles.h1.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '姓名将用于审核和统计，请填写真实姓名',
                      style: AppTextStyles.body.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '真实姓名',
                        style: AppTextStyles.sm.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '2-20 个字符',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          size: 18,
                          color: c.textSecondary,
                        ),
                      ),
                      style: AppTextStyles.body.copyWith(color: c.textPrimary),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AppButton.gradient(
                  label: '保存',
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}