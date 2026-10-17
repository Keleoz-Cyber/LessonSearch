import 'package:flutter/material.dart';

import '../design_system/colors.dart';
import '../design_system/tokens.dart';
import '../design_system/typography.dart';

/// Owns one cancellable loading route. Closing this handle never pops a page.
class LoadingDialogHandle {
  LoadingDialogHandle._(this._navigator, this._route);
  final NavigatorState _navigator;
  final DialogRoute<void> _route;

  static LoadingDialogHandle show(
    BuildContext context, {
    String message = '正在加载...',
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
    navigator.push(route);
    return LoadingDialogHandle._(navigator, route);
  }

  bool close() {
    if (!_navigator.mounted || !_route.isActive) return false;
    _navigator.removeRoute(_route);
    return true;
  }
}

/// 加载遮罩：覆盖在页面内容上方，半透明背景 + 居中转圈
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: isLoading,
          child: AbsorbPointer(absorbing: isLoading, child: child),
        ),
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: c.bgElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.borderDefault),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.brandPrimary),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        message!,
                        style: AppTextStyles.sm.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
