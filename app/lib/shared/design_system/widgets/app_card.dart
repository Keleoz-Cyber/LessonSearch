import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;

    final borderColor = selected
        ? c.brandPrimary
        : c.borderSubtle;
    final bgColor = selected ? c.brandSubtle : c.bgSurface;

    final shadows = brightness == Brightness.light
        ? <BoxShadow>[
            const BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ]
        : const <BoxShadow>[];

    final card = AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.fast,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: card,
      ),
    );
  }
}
