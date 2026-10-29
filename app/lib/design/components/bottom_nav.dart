import 'package:flutter/material.dart';

import '../../core/format/digits.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';

/// The five root destinations, right to left.
enum MadarTab { matches, mySatellites, frequencies, favorites, more }

/// The phone app's bottom navigation: five destinations, an accent pill behind the
/// current icon, and the Favorites badge in `live` (the only badge with that colour).
class MadarBottomNav extends StatelessWidget {
  const MadarBottomNav({
    super.key,
    required this.current,
    this.onSelect,
    this.favoritesBadge = 0,
  });

  final MadarTab current;
  final ValueChanged<MadarTab>? onSelect;
  final int favoritesBadge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final items = <(MadarTab, String, IconData, int)>[
      (MadarTab.matches, l.navMatches, Icons.sports_soccer, 0),
      (MadarTab.mySatellites, l.navSatellites, Icons.satellite_alt, 0),
      (MadarTab.frequencies, l.navFrequencies, Icons.show_chart, 0),
      (MadarTab.favorites, l.navFavorites, Icons.star_outline, favoritesBadge),
      (MadarTab.more, l.navMore, Icons.grid_view, 0),
    ];
    return Container(
      height: MadarLayout.bottomNavHeight,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _NavItem(
                label: item.$2,
                icon: item.$3,
                badge: item.$4,
                current: item.$1 == current,
                onTap: onSelect == null ? null : () => onSelect!(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.badge,
    required this.current,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final int badge;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      selected: current,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MadarSpace.s12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: MadarSpace.s3,
                      vertical: MadarSpace.s1,
                    ),
                    decoration: BoxDecoration(
                      color: current ? colors.accentContainer : null,
                      borderRadius: BorderRadius.circular(MadarRadii.pill),
                    ),
                    child: Icon(
                      icon,
                      size: MadarText.textStrong.fontSize,
                      color: current ? colors.accentText : colors.textSecondary,
                    ),
                  ),
                  if (badge > 0)
                    PositionedDirectional(
                      top: -MadarSpace.s1,
                      end: -MadarSpace.s1,
                      child: Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: MadarSpace.s1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.live,
                          borderRadius: BorderRadius.circular(MadarRadii.pill),
                        ),
                        child: Text(
                          MadarDigits.plain(badge),
                          style: MadarText.textMicro.copyWith(color: colors.textOnInverse),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(
                label,
                style: MadarText.textMicro.copyWith(
                  color: current ? colors.accentText : colors.textSecondary,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
