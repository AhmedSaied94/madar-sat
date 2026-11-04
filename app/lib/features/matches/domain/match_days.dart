import '../../../core/format/local_day.dart';
import '../../../core/network/generated/models/match_summary.dart';

/// The two tabs a screen of matches has: what is coming, and what has been played (S7, S8).
enum MatchTab { upcoming, results }

/// One local day of matches, already in the tab's order.
class MatchDay {
  const MatchDay({required this.day, required this.matches});

  /// A local calendar date (`DateTime(y, m, d)`), never an instant.
  final DateTime day;
  final List<MatchSummary> matches;
}

/// [rows] grouped by the local day of their kickoff: soonest first on the upcoming tab,
/// latest first on the results tab, matches inside a day ordered the same way.
///
/// The day is the local date of `kickoff_at`, never `match_date` (`LocalDays`), and
/// [offsetAt] carries the S15 zone so 23:30 in the chosen zone is listed under its own day.
/// A match with no kickoff keeps the day `match_date` gives it and sits at the end of that
/// day's list, as it does on S2. One rule, so S7 and S8 never disagree about a day.
List<MatchDay> matchDays(
  List<MatchSummary> rows, {
  required MatchTab tab,
  UtcOffsetAt? offsetAt,
}) {
  final sorted = [...rows]..sort((a, b) => tab == MatchTab.upcoming ? _soonest(a, b) : _latest(a, b));
  final groups = LocalDays.group(sorted, offsetAt: offsetAt);
  final days = groups.keys.toList()..sort();
  if (tab == MatchTab.results) {
    // `LocalDays` always lists a day soonest first; «النتائج» reads it the other way, and its
    // days descend too, so the latest result is the first thing on screen.
    final descending = days.reversed.toList(growable: false);
    return [
      for (final day in descending)
        MatchDay(
          day: day,
          matches: [...groups[day]!.timed.reversed, ...groups[day]!.tbd],
        ),
    ];
  }
  return [
    for (final day in days)
      MatchDay(day: day, matches: [...groups[day]!.timed, ...groups[day]!.tbd]),
  ];
}

/// True when the tab has anything to draw.
bool hasMatchDays(List<MatchDay> days) => days.any((day) => day.matches.isNotEmpty);

int _soonest(MatchSummary a, MatchSummary b) {
  final byKickoff = _compareKickoff(a, b);
  return byKickoff != 0 ? byKickoff : a.id.compareTo(b.id);
}

int _latest(MatchSummary a, MatchSummary b) {
  final byKickoff = _compareKickoff(b, a);
  return byKickoff != 0 ? byKickoff : b.id.compareTo(a.id);
}

/// A match with no kickoff sorts after one that has it, whichever way the list runs.
int _compareKickoff(MatchSummary a, MatchSummary b) {
  final kickoffA = a.kickoffAt;
  final kickoffB = b.kickoffAt;
  if (kickoffA == null && kickoffB == null) return 0;
  if (kickoffA == null) return 1;
  if (kickoffB == null) return -1;
  return kickoffA.compareTo(kickoffB);
}
