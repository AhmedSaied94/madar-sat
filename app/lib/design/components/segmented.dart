import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';

class SegmentedOption<T> {
  const SegmentedOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Two to four mutually exclusive options on a `surface-2` track; the selected segment
/// is raised (FormControls README).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  }) : assert(options.length >= 2 && options.length <= 4, 'a segmented control has 2 to 4 options');

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsets.all(MadarSpace.s1),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: MadarSpace.s1),
            Expanded(
              child: _Segment(
                label: options[i].label,
                icon: options[i].icon,
                selected: options[i].value == selected,
                onTap: () => onChanged(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final foreground = selected ? colors.textPrimary : colors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MadarRadii.md),
          child: Container(
            height: MadarSpace.s8 + MadarSpace.s1,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.segmentedOn : null,
              borderRadius: BorderRadius.circular(MadarRadii.md),
              boxShadow: selected ? context.madarShadows.shadowSubtle : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: MadarText.textBody.fontSize, color: foreground),
                  const SizedBox(width: MadarSpace.s1),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MadarText.textLabel.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
