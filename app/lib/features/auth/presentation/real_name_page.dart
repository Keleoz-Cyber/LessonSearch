import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      Toast.show(context, '姓名长度应为2-20个字符');
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('完善信息'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Icon(
                      Icons.badge_outlined,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '请输入您的真实姓名',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '姓名将用于审核和统计，请填写真实姓名',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '真实姓名',
                        hintText: '2-20个字符',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
