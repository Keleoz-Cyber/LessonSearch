import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';

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
            children: [
              if (hintText != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    hintText!,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (secondary != null) ...[
                    secondary!,
                    const SizedBox(width: 12),
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
