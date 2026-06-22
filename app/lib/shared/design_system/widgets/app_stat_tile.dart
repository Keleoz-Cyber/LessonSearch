import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// 大方块统计磁贴：图标 + 大数字 + 标签 + 色调。
///
/// 用于"本周统计"三栏布局（"迟到/早退 / 旷课 / 已审核"）。
class AppStatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const AppStatTile({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.xs),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: count),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '$value',
              style: AppTextStyles.withTabular(AppTextStyles.h1).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.xs.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
