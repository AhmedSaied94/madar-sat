import 'package:flutter/material.dart';

import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/match_row.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/matches_day.dart';
import '../../../core/config/media_image.dart';

/// A competition on S2: its header (logo, name, stage) over a card of its match rows.
class CompetitionSection extends StatelessWidget {
  const CompetitionSection({
    super.key,
    required this.group,
    required this.now,
    required this.onOpen,
  });

  final CompetitionGroup group;
  final DateTime now;
  final ValueChanged<MatchSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final competition = group.competition;
    final logo = competition.logo;
    return _GroupSection(
      header: _GroupHeader(
        title: competition.name,
        // The group's own stage, only when every match in it shares one: the first match's
        // round must not label a group that mixes rounds (constitution II).
        stage: group.stage,
        leading: LogoTile(
          kind: LogoTileKind.competition,
          logo: mediaImage(context, logo),
          size: _logoSize,
        ),
      ),
      matches: group.matches,
      now: now,
      onOpen: onOpen,
    );
  }
}

/// The «موعد لم يُحدد» group: matches whose kickoff is not known yet, at the end of a day.
class TbdSection extends StatelessWidget {
  const TbdSection({super.key, required this.matches, required this.now, required this.onOpen});

  final List<MatchSummary> matches;
  final DateTime now;
  final ValueChanged<MatchSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return _GroupSection(
      header: _GroupHeader(
        title: l.s2TbdGroup,
        leading: SizedBox(
          width: _logoSize,
          height: _logoSize,
          child: Icon(Icons.schedule, size: MadarText.textLabel.fontSize, color: colors.textTertiary),
        ),
      ),
      matches: matches,
      now: now,
      onOpen: onOpen,
    );
  }
}

const double _logoSize = MadarSpace.s6 + MadarSpace.s1;

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.header,
    required this.matches,
    required this.now,
    required this.onOpen,
  });

  final Widget header;
  final List<MatchSummary> matches;
  final DateTime now;
  final ValueChanged<MatchSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final radius = BorderRadius.circular(MadarRadii.xl);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: MadarSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: MadarSpace.s2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface1,
              borderRadius: radius,
              border: Border.all(color: colors.divider),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < matches.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: MadarLine.hairline,
                        thickness: MadarLine.hairline,
                        color: colors.divider,
                      ),
                    MatchRow(
                      key: ValueKey(matches[index].id),
                      match: matches[index],
                      now: now,
                      onTap: () => onOpen(matches[index]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.leading, this.stage});

  final String title;
  final String? stage;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final stage = this.stage;
    return Semantics(
      header: true,
      label: stage == null ? title : '$title${l.listSeparator}$stage',
      excludeSemantics: true,
      child: Row(
        children: [
          leading,
          const SizedBox(width: MadarSpace.s2),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MadarText.textStrong.copyWith(color: colors.textPrimary),
            ),
          ),
          if (stage != null && stage.isNotEmpty) ...[
            const SizedBox(width: MadarSpace.s2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(MadarRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s2,
                  vertical: MadarSpace.s1,
                ),
                child: Text(
                  stage,
                  maxLines: 1,
                  style: MadarText.textMicro.copyWith(color: colors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
