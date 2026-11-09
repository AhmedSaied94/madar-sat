import '../../../core/network/generated/models/match_event.dart';
import '../../../core/network/generated/models/match_event_side.dart';
import '../../../core/network/generated/models/match_event_type.dart';
import '../../../core/network/generated/models/score.dart';
import '../../../core/network/generated/models/status.dart';
import '../../live/live_merge.dart';

/// The period markers, derived from a minute because the API has no period on an event (R17).
enum TimelineMarkerKind { kickoff, secondHalf, extraTime }

/// One row of S3's timeline.
sealed class TimelineRow {
  const TimelineRow();
}

final class TimelineMarker extends TimelineRow {
  const TimelineMarker(this.kind);

  final TimelineMarkerKind kind;
}

final class TimelineEventRow extends TimelineRow {
  const TimelineEventRow(this.event, {this.runningScore});

  final MatchEvent event;

  /// The score after this goal, or null when it isn't a goal or the goals don't add up.
  final ({int home, int away})? runningScore;
}

const Set<MatchEventType> _goalTypes = {
  MatchEventType.goal,
  MatchEventType.ownGoal,
  MatchEventType.penalty,
};

final RegExp _minutePattern = RegExp(r'^\s*(\d+)(?:\s*\+\s*(\d+))?');

/// The rows for [events], as `EventTimeline`'s README orders them: newest first while in play,
/// chronological otherwise (FR-052).
///
/// A goal shows a running score only when the known goal-type events add up to [score] on both
/// sides, and none is ever invented (FR-053). An event of a type or side this build doesn't
/// know is left out rather than guessed.
List<TimelineRow> buildTimeline(List<MatchEvent> events, Score? score, Status status) {
  final known = [
    for (final event in events)
      if (event.type != MatchEventType.$unknown && event.side != MatchEventSide.$unknown) event,
  ];
  if (known.isEmpty) return const [];

  final ordered = _inMatchOrder(known);
  final addsUp = _goalsAddUp(ordered, score);
  final rows = <TimelineRow>[const TimelineMarker(TimelineMarkerKind.kickoff)];
  var period = 0;
  var home = 0;
  var away = 0;
  for (final (:event, :minute) in ordered) {
    final eventPeriod = _periodOf(minute);
    for (; period < eventPeriod; period++) {
      rows.add(
        TimelineMarker(period == 0 ? TimelineMarkerKind.secondHalf : TimelineMarkerKind.extraTime),
      );
    }
    final isGoal = _goalTypes.contains(event.type);
    if (isGoal && event.side == MatchEventSide.home) home++;
    if (isGoal && event.side == MatchEventSide.away) away++;
    rows.add(
      TimelineEventRow(event, runningScore: isGoal && addsUp ? (home: home, away: away) : null),
    );
  }
  return isInPlayStatus(status) ? rows.reversed.toList() : rows;
}

typedef _Timed = ({MatchEvent event, (int, int) minute});

/// A stable sort by minute. A minute it can't read takes the one before it, so it keeps its
/// place in the list the server sorted.
List<_Timed> _inMatchOrder(List<MatchEvent> events) {
  var last = (0, 0);
  final timed = <_Timed>[];
  for (final event in events) {
    last = _parseMinute(event.minute) ?? last;
    timed.add((event: event, minute: last));
  }
  final indexed = timed.indexed.toList()
    ..sort((a, b) {
      final byBase = a.$2.minute.$1.compareTo(b.$2.minute.$1);
      if (byBase != 0) return byBase;
      final byStoppage = a.$2.minute.$2.compareTo(b.$2.minute.$2);
      return byStoppage != 0 ? byStoppage : a.$1.compareTo(b.$1);
    });
  return [for (final entry in indexed) entry.$2];
}

(int, int)? _parseMinute(String minute) {
  final match = _minutePattern.firstMatch(minute);
  if (match == null) return null;
  return (int.parse(match.group(1)!), int.tryParse(match.group(2) ?? '') ?? 0);
}

/// 0 up to 45+, 1 up to 90+, 2 after: a stoppage minute like `45+2` belongs to its half.
int _periodOf((int, int) minute) => minute.$1 <= 45 ? 0 : (minute.$1 <= 90 ? 1 : 2);

bool _goalsAddUp(List<_Timed> events, Score? score) {
  if (score == null) return false;
  final goals = events.where((entry) => _goalTypes.contains(entry.event.type));
  final home = goals.where((entry) => entry.event.side == MatchEventSide.home).length;
  final away = goals.where((entry) => entry.event.side == MatchEventSide.away).length;
  return home == score.home && away == score.away;
}
