import 'package:flutter/material.dart';

import '../../../core/l10n/dates.dart';
import '../../../core/network/generated/models/competition_ref.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/match_row.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/team_matches.dart';

/// S7's matches, grouped by the local day of their kickoff: a date heading, then that day's
/// rows in a card. The rows are `MatchRow`, as on S2, and open S3.
class TeamMatchesList extends StatelessWidget {
  const TeamMatchesList({
    super.key,
    required this.days,
    required this.tab,
    required this.now,
    required this.onOpen,
    required this.followedTeams,
  });

  final List<TeamMatchDay> days;
  final TeamTab tab;
  final DateTime now;
  final ValueChanged<MatchSummary> onOpen;

  /// The followed teams, so a row draws the star S2 draws.
  final Set<int> followedTeams;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          _DayHeader(day: day.day, matches: day.matches),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.madarColors.surface1,
                borderRadius: BorderRadius.circular(MadarRadii.xl),
                border: Border.all(color: context.madarColors.divider, width: MadarLine.hairline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MadarRadii.xl),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: day.matches.length,
                  itemBuilder: (context, index) {
                    final match = day.matches[index];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index != 0)
                          Divider(
                            height: MadarLine.hairline,
                            thickness: MadarLine.hairline,
                            color: context.madarColors.divider,
                          ),
                        MatchRow(
                          key: ValueKey(match.id),
                          match: match,
                          now: now,
                          followed: followedTeams.contains(match.home.id) ||
                              followedTeams.contains(match.away.id),
                          onTap: () => onOpen(match),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// «الخميس 29 أكتوبر», with the round beside it when the whole day is one competition's round
/// (a day of two competitions is never labelled with one of them, constitution II).
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.matches});

  final DateTime day;
  final List<MatchSummary> matches;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final stage = _stage(l);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s5,
        MadarSpace.s4,
        MadarSpace.s5,
        MadarSpace.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              MadarDates.full(l, day),
              style: MadarText.textLabel.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (stage != null)
            Flexible(
              child: Text(
                stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: MadarText.textCaption.copyWith(color: colors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  /// «الدوري المصري · الجولة 8» when every match of the day shares its competition and round.
  String? _stage(AppLocalizations l) {
    final withKickoff = matches.where((match) => match.kickoffAt != null).toList(growable: false);
    if (withKickoff.isEmpty) return null;
    final first = withKickoff.first.competition;
    final same = withKickoff.every(
      (match) =>
          match.competition.id == first.id &&
          match.competition.name == first.name &&
          match.competition.stage == first.stage,
    );
    if (!same) return null;
    return _competitionLine(first);
  }

  static String _competitionLine(CompetitionRef competition) {
    final stage = competition.stage;
    return stage == null ? competition.name : '${competition.name} · $stage';
  }
}
