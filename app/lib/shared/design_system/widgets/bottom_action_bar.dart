import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class BottomActionBar extends StatelessWidget {
  /// 顶部可选信息文字（如"已选 3 个任务，共 90 条记录"）
  final String? hintText;

  /// 主操作按钮（必填）
  final Widget primary;

  /// 副操作按钮（可选，左侧）
  final Widget? secondary;

  const BottomActionBar({
    super.key,
    this.hintText,
    required this.primary,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    final shadows = brightness == Brightness.light
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ]
        : const <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        color: c.bgSurface,
        border: Border(top: BorderSide(color: c.borderSubtle)),
        boxShadow: shadows,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hintText != null) ...[
                Text(
                  hintText!,
                  style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  if (secondary != null) ...[
                    // secondary 用 Flexible 包裹，避免在窄屏上挤压 primary 按钮。
                    // FittedBox/intrinsic 由 secondary 自身处理。
                    Flexible(child: secondary!),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(child: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
