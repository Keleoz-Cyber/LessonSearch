import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum AppButtonVariant { primary, secondary, ghost, gradient }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.gradient({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.gradient;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = widget.onPressed == null || widget.loading;

    final height = switch (widget.size) {
      AppButtonSize.sm => 32.0,
      AppButtonSize.md => 40.0,
      AppButtonSize.lg => 48.0,
    };
    final paddingX = switch (widget.size) {
      AppButtonSize.sm => 12.0,
      AppButtonSize.md => 16.0,
      AppButtonSize.lg => 20.0,
    };
    final textStyle = switch (widget.size) {
      AppButtonSize.sm =>
        AppTextStyles.sm.copyWith(fontWeight: FontWeight.w500),
      AppButtonSize.md => AppTextStyles.bodyMedium,
      AppButtonSize.lg => AppTextStyles.bodyMedium
          .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    };

    final fg = switch (widget.variant) {
      AppButtonVariant.primary => c.onBrand,
      AppButtonVariant.gradient => c.onBrand,
      AppButtonVariant.secondary => c.textPrimary,
      AppButtonVariant.ghost => c.textPrimary,
    };

    final bgDecoration = switch (widget.variant) {
      AppButtonVariant.primary => BoxDecoration(
          color: disabled ? c.borderSubtle : c.brandPrimary,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.gradient => BoxDecoration(
          gradient: disabled ? null : c.brandGradient,
          color: disabled ? c.borderSubtle : null,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.secondary => BoxDecoration(
          color: c.bgSurface,
          border: Border.all(color: c.borderDefault),
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
      AppButtonVariant.ghost => BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
    };

    Widget content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          )
        else if (widget.leadingIcon != null)
          Icon(widget.leadingIcon, size: 16, color: fg),
        if ((widget.loading || widget.leadingIcon != null))
          const SizedBox(width: 8),
        Text(widget.label,
            style: textStyle.copyWith(color: disabled ? c.textDisabled : fg)),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: 16, color: fg),
        ],
      ],
    );

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.96 : 1.0,
        duration: AppDuration.fast,
        curve: AppCurves.fast,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : widget.onPressed,
            onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
            onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
            onTapCancel:
                disabled ? null : () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(AppRadius.normal),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              curve: AppCurves.fast,
              height: height,
              padding: EdgeInsets.symmetric(horizontal: paddingX),
              decoration: bgDecoration,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
