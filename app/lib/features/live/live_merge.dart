import '../../core/format/time.dart';
import '../../core/network/generated/models/live_state.dart';
import '../../core/network/generated/models/match_summary.dart';
import '../../core/network/generated/models/status.dart';

/// True for the four states in which a match is being played.
bool isInPlayStatus(Status status) => switch (status) {
      Status.live || Status.halftime || Status.extraTime || Status.penalties => true,
      _ => false,
    };

/// A cached row as the user may see it.
///
/// Live states come only from `/v1/live`, in memory (FR-047). A copy from drift that says a
/// match is in play is only what the server said some time ago, so with no live state to
/// confirm it, it becomes the quiet clock-estimated «مباشر» with no score and no minute
/// (constitution II, SC-008), never a live score that may be hours old.
MatchSummary withLiveState(MatchSummary match, LiveState? live) {
  if (live != null) {
    return match.copyWith(
      status: live.status,
      statusLabel: live.statusLabel,
      period: live.period,
      // An estimated state has no feed behind it, so it carries no score or minute.
      minute: live.estimated ? null : live.minute,
      score: live.estimated ? null : live.score,
      estimated: live.estimated,
    );
  }
  if (isInPlayStatus(match.status)) {
    return match.copyWith(
      status: Status.live,
      statusLabel: null,
      period: null,
      minute: null,
      score: null,
      estimated: true,
    );
  }
  return match;
}

/// [withLiveState] for a whole list, matching each row to its state by match id.
List<MatchSummary> applyLiveStates(List<MatchSummary> rows, Map<int, LiveState> live) => [
      for (final row in rows) withLiveState(row, live[row.id]),
    ];

/// True when something in [rows] is in play or kicks off within the hour, which is when
/// `/v1/live` is worth polling (FR-047).
bool hasLiveOrImminent(Iterable<MatchSummary> rows, {required DateTime now}) => rows.any(
      (row) =>
          isInPlayStatus(row.status) ||
          (row.status == Status.scheduled &&
              row.kickoffAt != null &&
              MadarTime.isImminent(row.kickoffAt!, now: now)),
    );
