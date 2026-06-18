import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum StatusPillVariant { success, warning, danger, info, neutral }

class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillVariant variant;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  const StatusPill.success({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.success;
  const StatusPill.warning({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.warning;
  const StatusPill.danger({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.danger;
  const StatusPill.info({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.info;
  const StatusPill.neutral({super.key, required this.label, this.icon})
      : variant = StatusPillVariant.neutral;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (variant) {
      StatusPillVariant.success => c.stateSuccess,
      StatusPillVariant.warning => c.stateWarning,
      StatusPillVariant.danger => c.stateDanger,
      StatusPillVariant.info => c.stateInfo,
      StatusPillVariant.neutral => c.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.xs.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
