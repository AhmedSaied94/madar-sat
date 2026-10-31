import '../../../core/format/local_day.dart';
import '../../../core/format/retention.dart';
import '../../../core/network/generated/models/competition_ref.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_snapshot.dart';
import '../../live/live_merge.dart';

/// The chips above the list: every match of the day, or only the ones in play.
enum MatchesFilter { all, live }

/// A match in play, as the user may see it. Apply the live states first
/// (`applyLiveStates`): with no live state a cached in-play row is no longer live at all.
bool isInPlay(MatchSummary match) => isInPlayStatus(match.status);

/// One competition's matches of a day, in kickoff order.
class CompetitionGroup {
  const CompetitionGroup({required this.competition, required this.matches, this.stage});

  final CompetitionRef competition;
  final List<MatchSummary> matches;

  /// The round for the header, only when every match of the group is in the same round: a
  /// group of round 5 and round 8 matches has no single round to name (constitution II).
  final String? stage;
}

/// A local day as S2 lists it: competition groups, then the matches with no kickoff.
class DayGroups {
  const DayGroups({required this.competitions, required this.tbd});

  /// By admin priority (none last), then the group's earliest kickoff.
  final List<CompetitionGroup> competitions;

  /// Kickoff unknown: the «موعد لم يُحدد» group, last.
  final List<MatchSummary> tbd;

  bool get isEmpty => competitions.isEmpty && tbd.isEmpty;

  int get matchCount => tbd.length + competitions.fold(0, (sum, g) => sum + g.matches.length);
}

/// Groups [rows] into the local [day]'s competition groups (FR-040, FR-041).
///
/// A match belongs to the device-local date of its `kickoff_at`, never to `match_date`
/// (`LocalDays.group`); rows of other days are left out.
DayGroups groupDay(DateTime day, Iterable<MatchSummary> rows) {
  final local = LocalDays.group(rows)[day];
  if (local == null) return const DayGroups(competitions: [], tbd: []);

  final byCompetition = <String, List<MatchSummary>>{};
  for (final match in local.timed) {
    (byCompetition[_competitionKey(match.competition)] ??= []).add(match);
  }
  final groups = [
    for (final matches in byCompetition.values) _group(matches),
  ]..sort(_byPriorityThenKickoff);
  return DayGroups(competitions: groups, tbd: local.tbd);
}

CompetitionGroup _group(List<MatchSummary> matches) {
  final stages = {for (final match in matches) match.competition.stage};
  return CompetitionGroup(
    competition: matches.first.competition,
    matches: matches,
    stage: stages.length == 1 ? stages.single : null,
  );
}

/// An id is the identity of a competition; one without an id is told apart by its name.
String _competitionKey(CompetitionRef competition) =>
    competition.id != null ? 'id:${competition.id}' : 'name:${competition.name}';

int _byPriorityThenKickoff(CompetitionGroup a, CompetitionGroup b) {
  final priorityA = a.competition.priority;
  final priorityB = b.competition.priority;
  if (priorityA != priorityB) {
    if (priorityA == null) return 1;
    if (priorityB == null) return -1;
    return priorityA.compareTo(priorityB);
  }
  // `matches` is in kickoff order, so the first one is the group's earliest.
  final byKickoff = a.matches.first.kickoffAt!.compareTo(b.matches.first.kickoffAt!);
  if (byKickoff != 0) return byKickoff;
  return a.competition.name.compareTo(b.competition.name);
}

/// The days S2 pages through and the strip that shows them.
abstract final class MatchesDays {
  /// Where today sits among the kept days (yesterday comes first).
  static const int todayIndex = Retention.daysBack;

  static const int stripCells = 7;

  /// Yesterday through today + 6: the local days drift keeps (FR-046), earliest first.
  static List<DateTime> kept(DateTime today) => [
        for (var offset = -Retention.daysBack; offset <= Retention.daysAhead; offset++)
          LocalDays.add(today, offset),
      ];

  /// The [stripCells] days the strip draws: the first seven, sliding by the one cell the
  /// kept days exceed them by only when the last day is selected.
  static List<DateTime> stripWindow(List<DateTime> days, int selectedIndex) {
    final start = (selectedIndex - stripCells + 1).clamp(0, days.length - stripCells);
    return days.sublist(start, start + stripCells);
  }
}

/// One local day, ready to draw: the rows with the live states applied, and how fresh the
/// copy under them is.
class DayView {
  const DayView({required this.day, required this.snapshot, required this.rows});

  final DateTime day;

  /// What the repository emitted: the copy, when it was confirmed, and a failed
  /// revalidation, if there was one.
  final SwrSnapshot<List<MatchSummary>> snapshot;

  /// The rows after `applyLiveStates`.
  final List<MatchSummary> rows;

  int get liveCount => rows.where(isInPlay).length;

  DayGroups groups(MatchesFilter filter) =>
      groupDay(day, filter == MatchesFilter.live ? rows.where(isInPlay) : rows);

  /// The age the hint shows, or null while the copy is inside its five minutes (FR-046).
  Duration? staleAge(DateTime now) => snapshot.staleAge(Freshness.matches, now: now);
}
