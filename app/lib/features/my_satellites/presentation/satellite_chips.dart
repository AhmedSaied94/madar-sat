import 'package:flutter/material.dart';

import '../../../core/network/generated/models/satellite.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// The chips of S4: «الكل», then one per satellite of mine. Several can be on at once, which
/// the single-select `FilterChipRow` cannot do, so these share its look: the chosen chip is
/// inverted, and it carries a check so the state is never colour alone.
class SatelliteChips extends StatelessWidget {
  const SatelliteChips({
    super.key,
    required this.satellites,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
  });

  final List<Satellite> satellites;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s4,
        vertical: MadarSpace.s1,
      ),
      child: Row(
        children: [
          // «الكل» is the way back to every satellite of mine, so it is an action: it is
          // never the chosen chip (the design draws it plain while every satellite is on).
          _ChipFrame(label: l.filterAll, selected: false, onTap: onSelectAll),
          for (final satellite in satellites) ...[
            const SizedBox(width: MadarSpace.s2),
            SatelliteChip(
              satellite: satellite,
              selected: selectedIds.contains(satellite.id),
              onTap: () => onToggle(satellite.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// One satellite of mine as a chip.
class SatelliteChip extends StatelessWidget {
  const SatelliteChip({
    super.key,
    required this.satellite,
    required this.selected,
    required this.onTap,
  });

  final Satellite satellite;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      _ChipFrame(label: satellite.nameAr, selected: selected, onTap: onTap, checkable: true);
}

class _ChipFrame extends StatelessWidget {
  const _ChipFrame({
    required this.label,
    required this.selected,
    required this.onTap,
    this.checkable = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A chip that can be on shows a check when it is.
  final bool checkable;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final foreground = selected ? colors.textOnInverse : colors.textSecondary;
    return Semantics(
      button: true,
      selected: checkable ? selected : null,
      label: label,
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
                    if (checkable && selected) ...[
                      Icon(Icons.check, size: MadarText.textBody.fontSize, color: foreground),
                      const SizedBox(width: MadarSpace.s1),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: MadarText.textLabel.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
