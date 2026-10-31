import '../network/generated/models/match_summary.dart';

/// The zone offset at a UTC instant. Injectable so day logic is testable without the host
/// zone (research R19); it defaults to the platform zone.
typedef UtcOffsetAt = Duration Function(DateTime utc);

/// One local day of matches: those with a kickoff, in order, and those without one.
class DayMatches {
  const DayMatches({required this.timed, required this.tbd});

  /// Ordered by kickoff, then id.
  final List<MatchSummary> timed;

  /// Kickoff unknown (`time_tbd`): the «موعد لم يُحدد» group.
  final List<MatchSummary> tbd;

  bool get isEmpty => timed.isEmpty && tbd.isEmpty;
}

/// Device-local calendar days (FR-041).
///
/// A day is a plain local `DateTime(y, m, d)`; its API form is `yyyy-MM-dd` ([key]). A
/// match belongs to the local date of its `kickoff_at`, never to the server's `match_date`,
/// which is Cairo's date and is wrong for a fan in Casablanca or Riyadh. A match with no
/// kickoff has no instant to convert, so `match_date` is the only date it can have.
abstract final class LocalDays {
  /// The local day containing the UTC instant [instantUtc].
  static DateTime of(DateTime instantUtc, {UtcOffsetAt? offsetAt}) {
    final utc = instantUtc.toUtc();
    final offset = offsetAt?.call(utc) ?? utc.toLocal().timeZoneOffset;
    final wall = utc.add(offset);
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// Groups [matches] by local day.
  static Map<DateTime, DayMatches> group(
    Iterable<MatchSummary> matches, {
    UtcOffsetAt? offsetAt,
  }) {
    final timed = <DateTime, List<MatchSummary>>{};
    final tbd = <DateTime, List<MatchSummary>>{};
    for (final match in matches) {
      final kickoff = match.kickoffAt;
      if (kickoff == null) {
        final date = match.matchDate;
        (tbd[DateTime(date.year, date.month, date.day)] ??= []).add(match);
      } else {
        (timed[of(kickoff, offsetAt: offsetAt)] ??= []).add(match);
      }
    }
    final days = {...timed.keys, ...tbd.keys}.toList()..sort();
    return {
      for (final day in days)
        day: DayMatches(
          timed: [...?timed[day]]..sort(_byKickoff),
          tbd: [...?tbd[day]],
        ),
    };
  }

  /// `yyyy-MM-dd`, the form `match_windows.day` and the cache keys use.
  static String key(DateTime day) => '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime parse(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// [day] moved by [days] calendar days (not 24-hour steps, so DST cannot skip a day).
  static DateTime add(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

  static int _byKickoff(MatchSummary a, MatchSummary b) {
    final byTime = a.kickoffAt!.compareTo(b.kickoffAt!);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
