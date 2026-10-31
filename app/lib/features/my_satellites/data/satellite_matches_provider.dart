import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';

part 'satellite_matches_provider.g.dart';

/// What S4 asks for: one device-local day of matches carried on [satelliteIds].
///
/// Equal when the day and the set of satellites are, however the set was built, so the
/// provider family below reuses one stream per question.
class SatelliteMatchesQuery {
  SatelliteMatchesQuery({required DateTime day, required Iterable<int> satelliteIds})
      : day = DateTime(day.year, day.month, day.day),
        satelliteIds = List.unmodifiable({...satelliteIds}.toList()..sort());

  final DateTime day;

  /// Sorted, without duplicates: the order the request and the cache key use.
  final List<int> satelliteIds;

  @override
  bool operator ==(Object other) =>
      other is SatelliteMatchesQuery &&
      other.day == day &&
      other.satelliteIds.length == satelliteIds.length &&
      [for (var i = 0; i < satelliteIds.length; i++) other.satelliteIds[i] == satelliteIds[i]]
          .every((same) => same);

  @override
  int get hashCode => Object.hash(day, Object.hashAll(satelliteIds));
}

/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
///
/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).
@Riverpod(retry: _never)
class SatelliteMatches extends _$SatelliteMatches {
  @override
  Stream<SwrSnapshot<List<MatchSummary>>> build(SatelliteMatchesQuery query) => ref
      .watch(swrRepositoryProvider)
      .watchMatchesBySatellites(day: query.day, satelliteIds: query.satelliteIds.toSet());

  /// The poll: read again through the provider's own stream.
  void revalidate() => ref.invalidateSelf();

  /// Pull to refresh: the whole cycle, then a re-read.
  Future<void> refresh() async {
    try {
      await ref
          .read(swrRepositoryProvider)
          .watchMatchesBySatellites(day: query.day, satelliteIds: query.satelliteIds.toSet())
          .drain<void>();
    } on ApiFailure {
      // Nothing to add: the state shows the cached copy or the error.
    }
    ref.invalidateSelf();
  }
}

Duration? _never(int retryCount, Object error) => null;
