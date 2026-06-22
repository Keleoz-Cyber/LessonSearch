import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class AppInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffix;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.errorText != null;
    final accent = hasError
        ? c.stateDanger
        : _focused
            ? c.brandPrimary
            : c.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AnimatedDefaultTextStyle(
            duration: AppDuration.fast,
            curve: AppCurves.fast,
            style: AppTextStyles.sm.copyWith(
              color: hasError
                  ? c.stateDanger
                  : _focused
                      ? c.brandPrimary
                      : c.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            child: Text(widget.label!),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          style: AppTextStyles.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.body.copyWith(color: c.textTertiary),
            prefixIcon: widget.prefixIcon != null
                ? TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: accent),
                    duration: AppDuration.fast,
                    builder: (context, color, _) =>
                        Icon(widget.prefixIcon, size: 18, color: color),
                  )
                : null,
            suffix: widget.suffix,
            errorText: widget.errorText,
            errorStyle: AppTextStyles.sm.copyWith(color: c.stateDanger),
          ),
        ),
      ],
    );
  }
}
