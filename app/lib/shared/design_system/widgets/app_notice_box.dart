import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

/// 通知块：彩色背景 + 左侧色条 + 图标 + 标题 + 可选正文。
///
/// 用于 rejected/cancelled/sync-warning/error 等通知块。
/// 颜色建议传入 [AppColors.stateDanger] / [AppColors.stateWarning] 等。
class AppNoticeBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  const AppNoticeBox({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: AppTextStyles.sm.copyWith(color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
