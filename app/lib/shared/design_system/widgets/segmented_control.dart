import 'package:flutter/material.dart';

import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegmentedItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = AppTextStyles.bodyMedium;
        final widths = items.map((item) {
          final painter = TextPainter(
            text: TextSpan(text: item.label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          return painter.width + 28;
        }).toList();
        final available = constraints.maxWidth - 4;
        final scroll =
            !available.isFinite ||
            widths.any((w) => w > available / items.length);
        Widget segment(int index) {
          final item = items[index];
          final selected = item.value == value;
          return Semantics(
            button: true,
            selected: selected,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(item.value),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppDuration.fast,
                  constraints: const BoxConstraints(
                    minHeight: 48,
                    minWidth: 48,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c.bgSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: style.copyWith(
                      color: selected ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final row = Row(
          mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
          children: [
            for (var i = 0; i < items.length; i++)
              if (scroll) segment(i) else Expanded(child: segment(i)),
          ],
        );
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: c.bgMuted,
            borderRadius: BorderRadius.circular(AppRadius.normal),
            border: Border.all(color: c.borderSubtle),
          ),
          child: scroll
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                )
              : row,
        );
      },
    );
  }
}

class AppSegmentedItem<T> {
  final T value;
  final String label;
  const AppSegmentedItem({required this.value, required this.label});
}
