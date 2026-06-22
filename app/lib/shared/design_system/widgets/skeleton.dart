import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.md);
    return ClipRRect(
      borderRadius: radius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // shimmer 扫光：渐变从 -1.5 移动到 1.5（覆盖整宽 + 边缘留白）
          final t = _controller.value;
          final shift = -1.5 + t * 3.0;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: c.bgMuted,
              gradient: LinearGradient(
                begin: Alignment(shift - 0.6, 0),
                end: Alignment(shift + 0.6, 0),
                colors: [
                  c.bgMuted,
                  c.bgMuted.withValues(alpha: 0.4),
                  c.bgMuted,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;

  const SkeletonLine({super.key, this.width, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SkeletonLine(height: 16)),
              const SizedBox(width: AppSpacing.sm),
              SkeletonBox(
                width: 60,
                height: 20,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SkeletonLine(width: 180),
          const SizedBox(height: AppSpacing.xs),
          const SkeletonLine(height: 12, width: 120),
        ],
      ),
    );
  }
}
