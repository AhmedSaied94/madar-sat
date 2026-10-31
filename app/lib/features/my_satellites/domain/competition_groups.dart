import '../../../core/network/generated/models/competition_ref.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/generated/models/status.dart';

/// One competition's matches on S4: the header's competition and its rows in display order.
class CompetitionGroup {
  const CompetitionGroup({required this.competition, required this.matches, this.stage});

  final CompetitionRef competition;

  /// Display order: the unfinished matches by kickoff, then the finished ones (PB S4).
  final List<MatchSummary> matches;

  /// The round for the header, only when every match of the group is in the same round.
  final String? stage;

  DateTime? get earliestKickoff {
    DateTime? earliest;
    for (final match in matches) {
      final kickoff = match.kickoffAt;
      if (kickoff != null && (earliest == null || kickoff.isBefore(earliest))) {
        earliest = kickoff;
      }
    }
    return earliest;
  }
}

/// Groups [matches] by competition for S4: admin priority first (1 is the top, no priority
/// last), then the group's earliest kickoff. Inside a group the finished matches sink to the
/// bottom, and the rest keep their kickoff order, so a row never jumps on a refresh.
List<CompetitionGroup> groupByCompetition(Iterable<MatchSummary> matches) {
  final byCompetition = <String, List<MatchSummary>>{};
  for (final match in matches) {
    final competition = match.competition;
    final key = competition.id != null ? 'id:${competition.id}' : 'name:${competition.name}';
    (byCompetition[key] ??= []).add(match);
  }
  return [for (final rows in byCompetition.values) _group(rows)]..sort(_byRank);
}

CompetitionGroup _group(List<MatchSummary> rows) {
  final ordered = [...rows]..sort(_inGroupOrder);
  final stages = {for (final row in ordered) row.competition.stage};
  return CompetitionGroup(
    competition: ordered.first.competition,
    matches: ordered,
    stage: stages.length == 1 ? stages.single : null,
  );
}

int _inGroupOrder(MatchSummary a, MatchSummary b) {
  final byFinished = _finishedRank(a).compareTo(_finishedRank(b));
  if (byFinished != 0) return byFinished;
  final byKickoff = _compareNullsLast(a.kickoffAt, b.kickoffAt);
  return byKickoff != 0 ? byKickoff : a.id.compareTo(b.id);
}

int _finishedRank(MatchSummary match) => match.status == Status.finished ? 1 : 0;

int _byRank(CompetitionGroup a, CompetitionGroup b) {
  final byPriority = _compareNullsLast(a.competition.priority, b.competition.priority);
  if (byPriority != 0) return byPriority;
  final byKickoff = _compareNullsLast(a.earliestKickoff, b.earliestKickoff);
  if (byKickoff != 0) return byKickoff;
  final byName = a.competition.name.compareTo(b.competition.name);
  return byName != 0 ? byName : (a.competition.id ?? 0).compareTo(b.competition.id ?? 0);
}

int _compareNullsLast<T extends Comparable<Object>>(T? a, T? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
