import '../../../core/network/generated/models/live_state.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../live/live_merge.dart';

/// The fields of a [MatchDetail] that live merging and polling read, as the
/// [MatchSummary] those rules are written for.
MatchSummary summaryOfDetail(MatchDetail detail) => MatchSummary(
      id: detail.id,
      sport: detail.sport,
      kickoffAt: detail.kickoffAt,
      timeTbd: detail.timeTbd,
      matchDate: detail.matchDate,
      status: detail.status,
      estimated: detail.estimated,
      period: detail.period,
      minute: detail.minute,
      score: detail.score,
      statusLabel: detail.statusLabel,
      competition: detail.competition,
      home: detail.home,
      away: detail.away,
      broadcast: detail.broadcast,
      commentator: detail.commentator,
      updatedAt: detail.updatedAt,
    );

/// [detail] as the user may see it: the same rule as a match row ([withLiveState]).
///
/// Live states come only from `/v1/live`. A cached in-play detail with no live state
/// becomes the quiet estimated «مباشر» with no score or minute, and an estimated live
/// state never carries either (SC-008).
MatchDetail detailWithLiveState(MatchDetail detail, LiveState? live) {
  final merged = withLiveState(summaryOfDetail(detail), live);
  return detail.copyWith(
    status: merged.status,
    statusLabel: merged.statusLabel,
    period: merged.period,
    minute: merged.minute,
    score: merged.score,
    estimated: merged.estimated,
  );
}
