import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// 紧凑统计胶囊：标签 + 数字 + 色调。
///
/// 用于 dialog 内异常统计摘要（"迟到 3"、"缺勤 2"）。
/// 设 `compact: true` 可用于行内（如顶部统计栏"应交 5 / 已交 3 / 未交 2"）。
class AppStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool compact;

  const AppStatChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final padH = compact ? AppSpacing.sm : AppSpacing.md;
    final padV = compact ? 4.0 : 6.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.xs.copyWith(color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTextStyles.withTabular(AppTextStyles.bodyMedium).copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
