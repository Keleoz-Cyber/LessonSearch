import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';

/// 多段彩色进度条。
///
/// 每段对应 [ProgressSegment]，按 [ProgressSegment.value] 整数比例分配宽度。
/// [totalCount] 为整体计数；剩余部分（`totalCount - sum(segments.value)`）
/// 以 [AppColors.bgMuted] 灰色显示。
///
/// **行为约定**：
/// - 当 `totalCount == 0` 时显示纯灰色条。
/// - 当 segments 总和超出 `totalCount` 时，剩余 tail 不显示，
///   但段间比例保持，bar 仍能正常渲染（容错处理）。
/// - 调试模式下 `totalCount < 0` 或 `height <= 0` 会触发 assert。
class SegmentedProgressBar extends StatelessWidget {
  final List<ProgressSegment> segments;
  final int totalCount;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.segments,
    required this.totalCount,
    this.height = 6,
  })  : assert(totalCount >= 0, 'totalCount must be >= 0'),
        assert(height > 0, 'height must be > 0');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (totalCount <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(height: height, color: c.bgMuted),
      );
    }

    final processed = segments.fold<int>(0, (s, seg) => s + seg.value);
    final remaining = (totalCount - processed).clamp(0, totalCount);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final seg in segments)
              if (seg.value > 0)
                Flexible(
                  flex: seg.value,
                  child: Container(color: seg.color),
                ),
            if (remaining > 0)
              Flexible(
                flex: remaining,
                child: Container(color: c.bgMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class ProgressSegment {
  final int value;
  final Color color;
  const ProgressSegment({required this.value, required this.color})
      : assert(value >= 0, 'segment value must be >= 0');
}
