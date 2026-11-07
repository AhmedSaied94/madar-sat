import 'package:flutter/material.dart';

import '../../../core/format/digits.dart';
import '../../../core/format/time.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/network/generated/models/competition_ref.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/generated/models/score.dart';
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
/// is what may be shown. The whole hero reads as one Arabic label (§13.8), and the taps to S7
/// and S8 are button nodes of their own inside it: everything else is excluded, so nothing is
/// read twice.
class MatchHero extends StatelessWidget {
  const MatchHero({
    super.key,
    required this.match,
    this.now,
    this.onOpenTeam,
    this.onOpenCompetition,
    this.highlightScore = false,
  });

  final MatchDetail match;
  final DateTime? now;

  /// Opens S7 for the team that was tapped (its crest or its name). Null draws the hero
  /// without that action.
  final ValueChanged<int>? onOpenTeam;

  /// Opens S8 for the competition named above the teams. Null draws it as plain text.
  final ValueChanged<int>? onOpenCompetition;

  /// Whether a rising score draws the eye: the live center's flag (FR-054, SC-013).
  final bool highlightScore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final individual = match.sport == Sport.tennis;

    return Semantics(
      container: true,
      label: _semantics(context, l),
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
            _CompetitionLine(
              competition: match.competition,
              onTap: onOpenCompetition == null || match.competition.id == null
                  ? null
                  : () => onOpenCompetition!(match.competition.id!),
            ),
            const SizedBox(height: MadarSpace.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Team(
                    name: match.home.name,
                    logo: match.home.logo,
                    individual: individual,
                    onTap: onOpenTeam == null || match.home.id == null
                        ? null
                        : () => onOpenTeam!(match.home.id!),
                  ),
                ),
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s2),
                    child: SizedBox(
                      width: MadarSpace.s12 + MadarSpace.s8,
                      child: Center(
                        child: ScoreFlash(
                          score: match.score,
                          enabled: highlightScore,
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
                  ),
                ),
                Expanded(
                  child: _Team(
                    name: match.away.name,
                    logo: match.away.logo,
                    individual: individual,
                    onTap: onOpenTeam == null || match.away.id == null
                        ? null
                        : () => onOpenTeam!(match.away.id!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MadarSpace.s4),
            ExcludeSemantics(
              child: Row(
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
            ),
            // Before the last hour the status block only shows the time, so the hero says
            // how long the wait is; inside the hour the block's «بعد 25 د» takes over.
            if (_countdown(l) case final countdown?) ...[
              const SizedBox(height: MadarSpace.s2),
              ExcludeSemantics(
                child: Row(
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The kickoff's day on the chosen zone's calendar (S15), so the date reads with the time
  /// beside it. A match with no time still has its day: `matchDate` is a calendar date, not
  /// an instant, so no zone moves it.
  DateTime _day(BuildContext context) {
    final kickoff = match.kickoffAt;
    if (kickoff == null) return match.matchDate;
    return MadarDisplayScope.zoneOf(context).wallClock(kickoff);
  }

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
    return l.s3DateTime(MadarDates.full(l, _day(context)), time ?? l.timeTbd);
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
    parts.add(MadarDates.full(l, _day(context)));
    if (_countdown(l) case final countdown?) parts.add(countdown);
    return parts.join(l.listSeparator);
  }
}

class _CompetitionLine extends StatelessWidget {
  const _CompetitionLine({required this.competition, this.onTap});

  final CompetitionRef competition;

  /// Opens S8 for this competition (T086).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final stage = competition.stage;
    final line = Wrap(
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
    if (onTap == null) return ExcludeSemantics(child: line);
    return Semantics(
      container: true,
      button: true,
      label: competition.name,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        child: line,
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({
    required this.name,
    required this.logo,
    required this.individual,
    this.onTap,
  });

  final String name;
  final String? logo;
  final bool individual;

  /// Opens S7 for this team (T086). The crest and the name are the target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final content = Column(
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
    if (onTap == null) return ExcludeSemantics(child: content);
    return Semantics(
      container: true,
      button: true,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s1),
          child: content,
        ),
      ),
    );
  }
}

/// Highlights the score once when a side rises while it's on screen (FR-054), as `.big-sc.flash`
/// does: `accent-container` fading out over 1.2 s.
///
/// No highlight on first paint, on a fall, or when a score appears where there was none, and
/// none under reduced motion. At rest it paints nothing, so S3 looks as it did (SC-013).
class ScoreFlash extends StatefulWidget {
  const ScoreFlash({super.key, required this.score, required this.enabled, required this.child});

  /// The highlight's surface, for a test to read.
  @visibleForTesting
  static const Key surfaceKey = ValueKey('score-flash-surface');

  final Score? score;
  final bool enabled;
  final Widget child;

  @override
  State<ScoreFlash> createState() => _ScoreFlashState();
}

class _ScoreFlashState extends State<ScoreFlash> with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1200);

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );
  bool _reducedMotion = false;

  @override
  void didUpdateWidget(ScoreFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.score;
    final now = widget.score;
    if (!widget.enabled || _reducedMotion || before == null || now == null) return;
    if (now.home > before.home || now.away > before.away) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final start = context.madarColors.accentContainer;
    final end = start.withValues(alpha: 0);
    return AnimatedBuilder(
      animation: _flash,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        key: ScoreFlash.surfaceKey,
        decoration: BoxDecoration(
          color: Color.lerp(start, end, Curves.easeOut.transform(_flash.value)),
          borderRadius: BorderRadius.circular(MadarRadii.md),
        ),
        child: child,
      ),
    );
  }
}
