import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';
import 'app_button.dart';

enum SyncBannerState { syncing, ready, failed, unknown }

class SyncStatusBanner extends StatefulWidget {
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
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _updateRotation();
  }

  @override
  void didUpdateWidget(SyncStatusBanner old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _updateRotation();
    }
  }

  void _updateRotation() {
    if (widget.state == SyncBannerState.syncing) {
      _rotation.repeat();
    } else {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (widget.state) {
      SyncBannerState.syncing => (c.stateInfo, Icons.sync),
      SyncBannerState.ready => (c.stateSuccess, Icons.check_circle_outline),
      SyncBannerState.failed => (c.stateDanger, Icons.error_outline),
      SyncBannerState.unknown => (c.stateWarning, Icons.cloud_off_outlined),
    };

    Widget iconWidget = Icon(icon, color: color, size: 18);
    if (widget.state == SyncBannerState.syncing) {
      iconWidget = RotationTransition(
        turns: _rotation,
        child: iconWidget,
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: AppTextStyles.bodyMedium.copyWith(color: c.textPrimary),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.description!,
                    style: AppTextStyles.sm.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton.ghost(
              label: widget.actionLabel!,
              onPressed: widget.onAction,
              size: AppButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}
