import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../db/app_database.dart';
import '../format/local_day.dart';
import 'api_failure.dart';
import 'etag_interceptor.dart';
import 'generated/models/match_summary.dart';

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

/// Stale-while-revalidate over drift (research R25, FR-046): emit the drift copy, then
/// revalidate with `If-None-Match`. A `200` replaces the copy and its ETag in one
/// transaction and emits again; a `304` only moves `fetched_at` and emits the same copy
/// again with the time the server confirmed it, so the screen's age hint does not call a
/// copy the server just confirmed stale.
///
/// Two paths share the conditional GET:
///
/// * [watchDay]: typed `matches` rows by device-local day, with `match_windows` holding
///   the day's ETag.
/// * [watchDocument]: a whole JSON document in `cached_documents` (match detail,
///   satellites, a satellite's channels, S4's filtered day).
///
/// Each stream ends after revalidating; a screen resubscribes (invalidates its provider)
/// to revalidate again. Live states are not cached here: they stay in memory (FR-047).
class SwrRepository {
  SwrRepository({required this._dio, required AppDatabase database}) : _db = database;

  final Dio _dio;
  final AppDatabase _db;

  /// One local day of matches. The ETag is stored under the day alone, so the request
  /// carries nothing else that could change the answer; a query that does (D3's own
  /// satellites) needs its own cache key, as `DocumentKeys.matchesBySatellites` has.
  Stream<SwrSnapshot<List<MatchSummary>>> watchDay(DateTime day) async* {
    final dayKey = LocalDays.key(day);
    final window = await _db.windowFor(dayKey);
    List<MatchSummary>? cached;
    if (window != null) {
      try {
        cached = await _db.readDay(day);
      } catch (_) {
        // Rows the current models cannot read (the contract moved on): treat the day as
        // uncached, so no ETag confirms them and the answer replaces them. Left to throw,
        // every open would fail here and the day would stay broken until it aged out.
        cached = null;
      }
      if (cached != null) yield SwrSnapshot(data: cached, fetchedAt: window.fetchedAt);
    }

    try {
      final bounds = _db.dayWindow(day);
      final fetched = await _conditionalGet(
        '/v1/matches',
        {
          'from': bounds.from.toUtc().toIso8601String(),
          'to': bounds.to.toUtc().toIso8601String(),
        },
        cached == null ? null : window?.etag,
      );
      final now = _db.now().toUtc();
      if (fetched.notModified) {
        if (cached == null) throw const ApiFailure();
        await _db.touchWindow(dayKey, now);
        yield SwrSnapshot(data: cached, fetchedAt: now);
        return;
      }
      final rows = _parseMatches(fetched.data);
      await _db.replaceDay(day, rows, etag: fetched.etag, fetchedAt: now);
      yield SwrSnapshot(data: await _db.readDay(day), fetchedAt: now);
    } catch (error) {
      final failure = _asFailure(error);
      if (cached == null) throw failure;
      yield SwrSnapshot(data: cached, fetchedAt: window!.fetchedAt, failure: failure);
    }
  }

  /// [parse] turns the envelope's `data` into the screen's model. It runs on the cached
  /// body and on a fresh one; a fresh body that does not parse is never stored.
  Stream<SwrSnapshot<T>> watchDocument<T>({
    required String key,
    required String path,
    Map<String, Object?> query = const {},
    required T Function(Object? data) parse,
  }) async* {
    var stored = await _db.documentFor(key);
    T? cached;
    if (stored != null) {
      try {
        cached = parse(jsonDecode(stored.body));
        yield SwrSnapshot(data: cached, fetchedAt: stored.fetchedAt);
      } catch (_) {
        // A body the current models cannot read (the contract moved on): refetch it.
        stored = null;
      }
    }

    try {
      final fetched = await _conditionalGet(path, query, stored?.etag);
      final now = _db.now().toUtc();
      if (fetched.notModified) {
        if (stored == null) throw const ApiFailure();
        await _db.touchDocument(key, now);
        yield SwrSnapshot(data: cached, fetchedAt: now);
        return;
      }
      final data = parse(fetched.data);
      await _db.putDocument(
        key: key,
        etag: fetched.etag,
        body: jsonEncode(fetched.data),
        fetchedAt: now,
      );
      yield SwrSnapshot(data: data, fetchedAt: now);
    } catch (error) {
      final failure = _asFailure(error);
      if (cached == null) throw failure;
      yield SwrSnapshot(data: cached, fetchedAt: stored!.fetchedAt, failure: failure);
    }
  }

  Future<_Fetched> _conditionalGet(
    String path,
    Map<String, Object?> query,
    String? etag,
  ) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        options: Options(
          headers: {'If-None-Match': ?etag},
          // The ETag lives in drift, not in the interceptor's memory.
          extra: {EtagInterceptor.bypassKey: true},
        ),
      );
      // Dio throws on 304, but an interceptor may resolve it into a response.
      if (response.statusCode == 304) return const _Fetched.notModified();
      return _Fetched.changed(
        etag: response.headers.value('etag'),
        data: _unwrap(response.data),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 304) return const _Fetched.notModified();
      throw ApiFailure.fromDio(error);
    }
  }

  /// The envelope's `data`, or the envelope's own `error.code` as a failure.
  static Object? _unwrap(Object? body) {
    if (body is! Map<String, Object?>) throw const ApiFailure();
    if (body['success'] != true) {
      final error = body['error'];
      final code = error is Map<String, Object?> ? error['code'] : null;
      throw ApiFailure(code: code is String ? code : null);
    }
    return body['data'];
  }

  static List<MatchSummary> _parseMatches(Object? data) => [
        for (final item in data! as List<Object?>)
          MatchSummary.fromJson((item! as Map).cast<String, Object?>()),
      ];

  static ApiFailure _asFailure(Object error) => error is ApiFailure ? error : const ApiFailure();
}

class _Fetched {
  const _Fetched.notModified()
      : notModified = true,
        etag = null,
        data = null;

  const _Fetched.changed({required this.etag, required this.data}) : notModified = false;

  final bool notModified;
  final String? etag;
  final Object? data;
}
