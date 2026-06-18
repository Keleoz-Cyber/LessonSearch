import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';

class SegmentedProgressBar extends StatelessWidget {
  /// 各段数据：value 表示数量；color 表示该段颜色。
  /// 总数 = totalCount。
  /// 已处理总数 = segments.sumOf(value)；剩余部分以 muted 灰色显示。
  final List<ProgressSegment> segments;
  final int totalCount;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.segments,
    required this.totalCount,
    this.height = 6,
  });

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
  const ProgressSegment({required this.value, required this.color});
}
