import 'package:flutter/material.dart';

import '../../../core/network/generated/models/competition_detail.dart';
import '../../../core/network/generated/models/rights_holder_ref.dart';
import '../../../core/network/generated/models/satellite_ref.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/button.dart';
import '../../../design/components/logo.dart';
import '../../../l10n/app_localizations.dart';

/// S8's header: the competition's logo and name, then the follow toggle and the shortcut that
/// scrolls to the rights section (§S8).
///
/// No hide/show: that arrives with S15's competition controls on D8. The whole block reads as
/// one Arabic label.
class CompetitionHeader extends StatelessWidget {
  const CompetitionHeader({
    super.key,
    required this.detail,
    required this.logo,
    required this.following,
    required this.onFollow,
    required this.showRightsShortcut,
    required this.onOpenRights,
  });

  final CompetitionDetail detail;
  final ImageProvider? logo;
  final bool following;
  final VoidCallback onFollow;

  /// True when the competition has rights holders to scroll to.
  final bool showRightsShortcut;
  final VoidCallback onOpenRights;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;

    return Semantics(
      container: true,
      label: detail.name,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s4,
          MadarSpace.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LogoTile(
                  kind: LogoTileKind.competition,
                  logo: logo,
                  fallbackText: detail.name,
                  size: MadarSpace.s12 + MadarSpace.s6,
                ),
                const SizedBox(width: MadarSpace.s4),
                Expanded(
                  child: Text(
                    detail.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MadarText.heading1.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MadarSpace.s4),
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    label: following ? l.s8FollowingCompetition : l.s8FollowCompetition,
                    icon: following ? Icons.star : Icons.star_border,
                    variant: following ? MadarButtonVariant.secondary : MadarButtonVariant.outline,
                    expanded: true,
                    onPressed: onFollow,
                  ),
                ),
                if (showRightsShortcut) ...[
                  const SizedBox(width: MadarSpace.s2),
                  MadarButton(
                    label: l.s8Rights,
                    icon: Icons.verified_outlined,
                    variant: MadarButtonVariant.secondary,
                    onPressed: onOpenRights,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «حقوق البث»: who carries the competition and on which satellites. The rows are not
/// tappable and show no chevron: S11.4 arrives on D7 (§S8).
class RightsHoldersSection extends StatelessWidget {
  const RightsHoldersSection({super.key, required this.holders});

  final List<RightsHolderRef> holders;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    if (holders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s5,
            MadarSpace.s6,
            MadarSpace.s5,
            MadarSpace.s2,
          ),
          child: Row(
            children: [
              Text(
                l.s8Rights,
                style: MadarText.textLabel.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: MadarSpace.s2),
              Text(
                l.s8RightsCount(holders.length),
                style: MadarText.textCaption.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: BorderRadius.circular(MadarRadii.xl),
              border: Border.all(color: colors.divider, width: MadarLine.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MadarRadii.xl),
              child: Column(
                children: [
                  for (final (index, holder) in holders.indexed) ...[
                    if (index != 0)
                      Divider(
                        height: MadarLine.hairline,
                        thickness: MadarLine.hairline,
                        color: colors.divider,
                      ),
                    RightsHolderRow(holder: holder),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One rights holder: its logo, its name and «هوت بيرد · 9 بطولات».
class RightsHolderRow extends StatelessWidget {
  const RightsHolderRow({super.key, required this.holder});

  final RightsHolderRef holder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellites = _satellites(l);
    final competitions = l.s8CompetitionsCount(holder.competitionCount);
    final line = satellites.isEmpty ? competitions : l.s8RightsLine(satellites, competitions);

    return Semantics(
      container: true,
      label: [holder.name, line].join(l.listSeparator),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s3,
          vertical: MadarSpace.s2,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
          child: Row(
            children: [
              LogoTile(
                kind: LogoTileKind.channel,
                fallbackText: holder.name,
                size: MadarSpace.s12 - MadarSpace.s2,
              ),
              const SizedBox(width: MadarSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EntityName(
                      holder.name,
                      style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: MadarSpace.s1),
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// «هوت بيرد، نايل سات»: the satellites it airs on, in the API's order.
  String _satellites(AppLocalizations l) {
    final names = [for (final SatelliteRef satellite in holder.satellites) satellite.nameAr];
    return names.join(l.listSeparator);
  }
}
