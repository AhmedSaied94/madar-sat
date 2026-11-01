import 'package:flutter/material.dart';

import '../../../core/format/digits.dart';
import '../../../core/format/time.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/network/generated/models/competition_ref.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/generated/models/sport.dart';
import '../../../core/network/generated/models/status.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/display_scope.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/status_block.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/media_image.dart';

/// The top of S3: the competition and stage, both teams with the status between them (home
/// on the right), and the kickoff date in words.
///
/// [match] is already merged with the live state (`detailWithLiveState`), so what it says
/// is what may be shown. The whole hero reads as one Arabic label.
class MatchHero extends StatelessWidget {
  const MatchHero({super.key, required this.match, this.now});

  final MatchDetail match;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final individual = match.sport == Sport.tennis;

    return Semantics(
      container: true,
      label: _semantics(context, l),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s4,
          MadarSpace.s3,
          MadarSpace.s4,
          MadarSpace.s4,
        ),
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(bottom: BorderSide(color: colors.divider, width: MadarLine.hairline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompetitionLine(competition: match.competition),
            const SizedBox(height: MadarSpace.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Team(name: match.home.name, logo: match.home.logo, individual: individual),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s2),
                  child: SizedBox(
                    width: MadarSpace.s12 + MadarSpace.s8,
                    child: Center(
                      child: StatusBlock(
                        status: match.status,
                        kickoff: match.kickoffAt,
                        score: match.score,
                        minute: match.minute,
                        estimated: match.estimated,
                        timeTbd: match.timeTbd,
                        now: now,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _Team(name: match.away.name, logo: match.away.logo, individual: individual),
                ),
              ],
            ),
            const SizedBox(height: MadarSpace.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: MadarText.textCaption.fontSize,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: MadarSpace.s2),
                Flexible(
                  child: Text(
                    _dateAndTime(context, l),
                    style: MadarText.textCaption.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
            // Before the last hour the status block only shows the time, so the hero says
            // how long the wait is; inside the hour the block's «بعد 25 د» takes over.
            if (_countdown(l) case final countdown?) ...[
              const SizedBox(height: MadarSpace.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: MadarText.textCaption.fontSize,
                    color: colors.accentText,
                  ),
                  const SizedBox(width: MadarSpace.s2),
                  Flexible(
                    child: Text(
                      countdown,
                      style: MadarText.textCaption.copyWith(color: colors.accentText),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The kickoff on the device's calendar. A match with no time still has its day.
  DateTime get _localDay => (match.kickoffAt ?? match.matchDate).toLocal();

  /// «تبدأ بعد 3 ساعات» while the kickoff is more than an hour away; null inside the hour
  /// (the status block counts it), once it has passed, or when there is no time to count.
  String? _countdown(AppLocalizations l) {
    final kickoff = match.kickoffAt;
    final now = this.now;
    if (now == null || kickoff == null || match.timeTbd || match.status != Status.scheduled) {
      return null;
    }
    final minutes = MadarTime.minutesUntil(kickoff, now: now);
    if (minutes <= 60) return null;
    if (minutes >= 24 * 60) return l.s3StartsInDays(minutes ~/ (24 * 60));
    if (minutes >= 120) return l.s3StartsInHours(minutes ~/ 60);
    return l.s3StartsInMinutes(minutes);
  }

  String _dateAndTime(BuildContext context, AppLocalizations l) {
    final time = match.timeTbd
        ? null
        : MadarTime.kickoff(match.kickoffAt, am: l.amMarker, pm: l.pmMarker, use24h: MadarDisplayScope.use24hOf(context), zone: MadarDisplayScope.zoneOf(context).fixed);
    return l.s3DateTime(MadarDates.full(l, _localDay), time ?? l.timeTbd);
  }

  String _semantics(BuildContext context, AppLocalizations l) {
    final parts = <String>[l.vs(match.away.name, match.home.name)];
    final score = match.score;
    String scoreWords() => l.scoreSemantics(
          MadarDigits.plain(score!.away),
          MadarDigits.plain(score.home),
        );
    switch (match.status) {
      case Status.scheduled:
        final time = match.timeTbd
            ? null
            : MadarTime.kickoff(match.kickoffAt, am: l.amMarker, pm: l.pmMarker, use24h: MadarDisplayScope.use24hOf(context), zone: MadarDisplayScope.zoneOf(context).fixed);
        parts.add(time ?? l.timeTbd);
      case Status.live:
        parts.add(l.live);
        if (!match.estimated) {
          if (match.minute != null) parts.add(l.minuteSemantics(match.minute!));
          if (score != null) parts.add(scoreWords());
        }
      case Status.halftime:
        parts.add(l.halftime);
        if (score != null) parts.add(scoreWords());
      case Status.finished:
        parts.add(l.finished);
        if (score != null) parts.add(scoreWords());
      case Status.extraTime:
        parts.add(l.extraTime);
      case Status.penalties:
        parts.add(l.penalties);
      case Status.postponed:
        parts.add(l.postponed);
      case Status.cancelled:
        parts.add(l.cancelled);
      case Status.abandoned:
        parts.add(l.abandoned);
      case Status.$unknown:
        break;
    }
    parts.add(match.competition.name);
    if (match.competition.stage != null) parts.add(match.competition.stage!);
    parts.add(MadarDates.full(l, _localDay));
    if (_countdown(l) case final countdown?) parts.add(countdown);
    return parts.join(l.listSeparator);
  }
}

class _CompetitionLine extends StatelessWidget {
  const _CompetitionLine({required this.competition});

  final CompetitionRef competition;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final stage = competition.stage;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: MadarSpace.s2,
      runSpacing: MadarSpace.s1,
      children: [
        LogoTile(
          kind: LogoTileKind.competition,
          logo: mediaImage(context, competition.logo),
          size: MadarSpace.s6,
        ),
        Text(
          competition.name,
          style: MadarText.textStrong.copyWith(color: colors.textPrimary),
        ),
        if (stage != null)
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MadarSpace.s2,
              vertical: MadarSpace.s1,
            ),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(MadarRadii.sm),
            ),
            child: Text(stage, style: MadarText.textCaption.copyWith(color: colors.textSecondary)),
          ),
      ],
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({required this.name, required this.logo, required this.individual});

  final String name;
  final String? logo;
  final bool individual;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!individual) ...[
          TeamCrest(
            name: name,
            logo: mediaImage(context, logo),
            size: MadarSpace.s12 + MadarSpace.s6,
          ),
          const SizedBox(height: MadarSpace.s2),
        ],
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: MadarText.heading2.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}
