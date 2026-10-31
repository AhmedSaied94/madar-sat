import '../format/local_day.dart';
import 'api_failure.dart';

/// How long a copy stays fresh before `StaleHint` shows its age (research R25).
abstract final class Freshness {
  static const Duration matches = Duration(minutes: 5);
  static const Duration matchDetail = Duration(minutes: 5);
  static const Duration satellites = Duration(hours: 24);
  static const Duration channels = Duration(hours: 24);
}

/// The `cached_documents` keys (research R25). One place, so a screen and its test agree.
abstract final class DocumentKeys {
  static const String satellites = 'satellites';

  static String matchDetail(int id) => 'match:$id';

  static String satelliteChannels(int satelliteId) => 'satellite:$satelliteId:channels';

  /// S4's day, filtered by satellite. It is a different query from S2's day, so it never
  /// goes through `matches` or `match_windows` (R25).
  static String matchesBySatellites(DateTime day, Set<int> satelliteIds) =>
      'matches:${LocalDays.key(day)}:sat:${_sortedIds(satelliteIds)}';
}

String _sortedIds(Set<int> ids) => (ids.toList()..sort()).join(',');

/// What a repository stream emits: the data, when it was last confirmed fresh, and the
/// failure of the revalidation that followed, if there was one.
///
/// [data] is null only on the first emission of a stream with nothing cached, which never
/// happens: that case emits nothing until the answer or the error arrives.
class SwrSnapshot<T> {
  const SwrSnapshot({this.data, this.fetchedAt, this.failure});

  final T? data;

  /// When the copy was last confirmed by the server (UTC); a `304` moves it.
  final DateTime? fetchedAt;

  /// Set when revalidating failed (offline, a server error, a body that did not parse).
  /// [data] is then the cached copy, never an empty replacement.
  final ApiFailure? failure;

  Duration? age(DateTime now) => fetchedAt == null ? null : now.toUtc().difference(fetchedAt!);

  /// True once the copy is older than [freshness], or has no fetch time.
  bool isStale(Duration freshness, {required DateTime now}) {
    final age = this.age(now);
    return age == null || age > freshness;
  }

  /// The age a `StaleHint` shows, or null while none is due: the copy is older than
  /// [freshness] (FR-046). The one rule for every screen, so a copy the server confirmed
  /// (a `304` moves [fetchedAt]) never reads as stale, and a failed revalidation of a copy
  /// still inside its target says nothing.
  Duration? staleAge(Duration freshness, {required DateTime now}) {
    final age = this.age(now);
    return age != null && age > freshness ? age : null;
  }
}
