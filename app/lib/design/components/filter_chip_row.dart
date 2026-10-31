import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'status_block.dart' show LiveDot;

class FilterChipItem<T> {
  const FilterChipItem({
    required this.value,
    required this.label,
    this.count,
    this.isLive = false,
  });

  final T value;
  final String label;

  /// Shown dimmed and tabular after the label; a count of zero is not drawn.
  final int? count;

  /// The live chip carries the pulsing `live` dot, the only chip allowed a status colour.
  final bool isLive;
}

/// Filter chips for the match list: single select, one row that scrolls sideways and never
/// wraps (Chip README). The selected chip is inverted.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterChipItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s1,
      ),
      child: Row(
        children: [
          for (final item in items) ...[
            if (item != items.first) const SizedBox(width: MadarSpace.s2),
            _Chip(
              label: item.label,
              count: item.count,
              isLive: item.isLive,
              selected: item.value == selected,
              onTap: () => onSelected(item.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLive,
    this.count,
  });

  final String label;
  final int? count;
  final bool isLive;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final shownCount = (count ?? 0) > 0 ? count : null;
    final semantic =
        shownCount == null ? label : '$label${l.listSeparator}${MadarDigits.plain(shownCount)}';
    return Semantics(
      button: true,
      selected: selected,
      label: semantic,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MadarRadii.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
            child: Center(
              child: Container(
                height: MadarSpace.s8 + MadarSpace.s1,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s3),
                decoration: BoxDecoration(
                  color: selected ? colors.textPrimary : null,
                  borderRadius: BorderRadius.circular(MadarRadii.pill),
                  border: selected
                      ? null
                      : Border.all(color: colors.dividerStrong, width: MadarLine.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      const LiveDot(),
                      const SizedBox(width: MadarSpace.s1),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: MadarText.textLabel.copyWith(
                        color: selected ? colors.textOnInverse : colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (shownCount != null) ...[
                      const SizedBox(width: MadarSpace.s1),
                      _Count(count: shownCount, selected: selected),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      constraints: const BoxConstraints(minWidth: MadarSpace.s5),
      height: MadarSpace.s5,
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s1),
      decoration: BoxDecoration(
        color: selected ? colors.textOnInverse.withValues(alpha: 0.22) : colors.surface3,
        borderRadius: BorderRadius.circular(MadarRadii.pill),
      ),
      child: Text(
        MadarDigits.plain(count),
        style: MadarText.textMicro.copyWith(
          color: selected ? colors.textOnInverse : colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
