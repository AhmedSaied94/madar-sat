import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';

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

List<MatchSummary> parseSatelliteMatches(Object? data) => [
      for (final item in data! as List<Object?>)
        MatchSummary.fromJson((item! as Map).cast<String, Object?>()),
    ];

/// S4's day, `/v1/matches?from&to&satellite_ids=…`, stale-while-revalidate.
///
/// It is a different question from S2's day, so it is cached as its own document under
/// `matches:<day>:sat:<ids>` and never goes through the `matches` table or `match_windows`
/// (research R25): written there it would replace S2's full day with a filtered one, and
/// filtering S2's rows locally would miss carriages, because a row's channel line holds at
/// most two.
class SatelliteMatchesRepository {
  const SatelliteMatchesRepository({required this._swr, required this._database});

  final SwrRepository _swr;
  final AppDatabase _database;

  Stream<SwrSnapshot<List<MatchSummary>>> watch(SatelliteMatchesQuery query) {
    final window = _database.dayWindow(query.day);
    return _swr.watchDocument<List<MatchSummary>>(
      key: DocumentKeys.matchesBySatellites(query.day, query.satelliteIds.toSet()),
      path: '/v1/matches',
      query: {
        'from': window.from.toUtc().toIso8601String(),
        'to': window.to.toUtc().toIso8601String(),
        'satellite_ids': query.satelliteIds.join(','),
      },
      parse: parseSatelliteMatches,
    );
  }
}

final satelliteMatchesRepositoryProvider = Provider<SatelliteMatchesRepository>(
  (ref) => SatelliteMatchesRepository(
    swr: ref.watch(swrRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);

/// No automatic retry: Riverpod would hold the state at loading for about 38 s while it
/// retried, and the error copy with «إعادة المحاولة» would not show (the S2 rule).
final satelliteMatchesProvider = StreamProvider.autoDispose
    .family<SwrSnapshot<List<MatchSummary>>, SatelliteMatchesQuery>(
  (ref, query) => ref.watch(satelliteMatchesRepositoryProvider).watch(query),
  retry: (retryCount, error) => null,
);
