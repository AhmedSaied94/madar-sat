import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/format/clock.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/generated/models/team_detail.dart';
import '../../../core/network/swr_providers.dart';
import '../../follows/data/follows_repository.dart';

part 'favorites_providers.g.dart';

/// «مبارياتي القادمة»: the next three matches of what the person follows (S9).
///
/// Read from drift, which already holds the kept days' matches (D2), so the section works
/// offline; a followed team or match with nothing in the window simply adds nothing. The
/// order is by kickoff, then id, so two matches at the same minute never swap places.
@riverpod
Future<List<MatchSummary>> favoriteUpcoming(Ref ref) async {
  final follows = ref.watch(followSetValueProvider);
  final now = ref.watch(clockProvider)().toUtc();
  final rows = await ref.watch(appDatabaseProvider).readAll();
  if (follows.isEmpty) return const [];
  final upcoming = [
    for (final match in rows)
      if (match.kickoffAt != null &&
          match.kickoffAt!.isAfter(now) &&
          (follows.matches.contains(match.id) ||
              follows.teams.contains(match.home.id) ||
              follows.teams.contains(match.away.id)))
        match,
  ]..sort((a, b) {
      final byKickoff = a.kickoffAt!.compareTo(b.kickoffAt!);
      return byKickoff != 0 ? byKickoff : a.id.compareTo(b.id);
    });
  return upcoming.take(3).toList(growable: false);
}

/// The followed teams with their names and competitions, from `/v1/teams/{id}` through the
/// SWR cache: S9 shows a team the cached matches know nothing about.
///
/// One request per followed team the first time, then a conditional `If-None-Match`; a team
/// that cannot be read is left out rather than drawn with a guessed name.
@riverpod
Future<List<TeamDetail>> favoriteTeams(Ref ref) async {
  final follows = ref.watch(followSetValueProvider);
  if (follows.teams.isEmpty) return const [];
  final repository = ref.watch(swrRepositoryProvider);
  final details = await Future.wait([
    for (final id in follows.teams)
      repository
          .watchTeamDetail(id)
          .firstWhere((snapshot) => snapshot.data != null)
          .then<TeamDetail?>((snapshot) => snapshot.data)
          .catchError((Object _) => null),
  ]);
  return [for (final detail in details) ?detail];
}

