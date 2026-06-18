import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';
import 'app_button.dart';

enum SyncBannerState { syncing, ready, failed, unknown }

class SyncStatusBanner extends StatelessWidget {
  final SyncBannerState state;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SyncStatusBanner({
    super.key,
    required this.state,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (state) {
      SyncBannerState.syncing => (c.stateInfo, Icons.sync),
      SyncBannerState.ready => (c.stateSuccess, Icons.check_circle_outline),
      SyncBannerState.failed => (c.stateDanger, Icons.error_outline),
      SyncBannerState.unknown => (c.stateWarning, Icons.cloud_off_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton.ghost(
              label: actionLabel!,
              onPressed: onAction,
              size: AppButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}
