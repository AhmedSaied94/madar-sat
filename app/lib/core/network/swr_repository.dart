import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../db/app_database.dart';
import '../format/local_day.dart';
import 'api_failure.dart';
import 'dio_failure.dart';
import 'etag_interceptor.dart';
import 'generated/export.dart';
import 'swr_snapshot.dart';

export 'swr_snapshot.dart';

/// Stale-while-revalidate over drift (research R25, FR-046): emit the drift copy, then
/// revalidate with `If-None-Match`. A `200` replaces the copy and its ETag in one
/// transaction and emits again; a `304` only moves `fetched_at` and emits the same copy
/// again with the time the server confirmed it, so the screen's age hint does not call a
/// copy the server just confirmed stale.
///
/// Every request goes through the generated client (`MadarApi`): the paths and query names
/// are the contract's, so a renamed operation breaks the build instead of the app. The
/// ETag and the `If-None-Match` header are the only things added around it.
///
/// Two cache shapes share the conditional GET:
///
/// * `watchDay`: typed `matches` rows by device-local day, with `match_windows` holding the
///   day's ETag.
/// * the document readers: a whole JSON body in `cached_documents` (match detail,
///   satellites, a satellite's channels, S4's filtered day).
///
/// Each stream ends after revalidating; a screen resubscribes (invalidates its provider)
/// to revalidate again. Live states are not cached here: they stay in memory (FR-047).
class SwrRepository {
  SwrRepository({required this._dio, required AppDatabase database}) : _db = database;

  /// The app's Dio. Each request below gets a request-scoped view of it ([_requestDio]) that
  /// keeps its base options, adapter, transformer and interceptors, because the ETag it
  /// sends comes from drift and not from `EtagInterceptor`'s memory, and two screens
  /// revalidating at once must not swap headers.
  final Dio _dio;
  final AppDatabase _db;

  /// One local day of matches. The ETag is stored under the day alone, so the request
  /// carries nothing else that could change the answer; the ranking D3 sends
  /// (`my_satellite_ids`) does change the channel line, so its ETag is kept under the day
  /// with the selection (M-R1-5) and changing satellites never reuses the old one.
  Stream<SwrSnapshot<List<MatchSummary>>> watchDay(
    DateTime day, {
    Set<int> mySatelliteIds = const {},
  }) async* {
    final dayKey = LocalDays.key(day);
    final selection = _sortedIds(mySatelliteIds);
    final windowKey = selection.isEmpty ? dayKey : '$dayKey|$selection';
    final window = await _db.windowFor(windowKey);
    List<MatchSummary>? cached;
    if (window != null) {
      try {
        cached = await _db.readDay(day);
      } catch (error, stackTrace) {
        // Rows the current models cannot read (the contract moved on): treat the day as
        // uncached, so no ETag confirms them and the answer replaces them. Left to throw,
        // every open would fail here and the day would stay broken until it aged out.
        _log('reading the cached day $dayKey failed', error, stackTrace);
        cached = null;
      }
      if (cached != null) yield SwrSnapshot(data: cached, fetchedAt: window.fetchedAt);
    }

    try {
      final bounds = _db.dayWindow(day);
      final fetched = await _conditional<List<MatchSummary>, EnvelopeListMatchSummary>(
        etag: cached == null ? null : window?.etag,
        send: (client) => client.listMatchesV1MatchesGet(
          from: bounds.from.toUtc(),
          to: bounds.to.toUtc(),
          mySatelliteIds: selection.isEmpty ? null : selection,
        ),
        unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
      );
      final now = _db.now().toUtc();
      if (fetched.notModified) {
        if (cached == null) throw const ApiFailure();
        await _db.touchWindow(windowKey, now);
        yield SwrSnapshot(data: cached, fetchedAt: now);
        return;
      }
      // A storage failure must not throw the fresh rows away: they are still what the
      // server said, and the next open re-reads the cache.
      var written = true;
      try {
        await _db.replaceDay(
          day,
          fetched.value!,
          etag: fetched.etag,
          fetchedAt: now,
          windowKey: windowKey,
        );
      } catch (error, stackTrace) {
        written = false;
        _log('writing the day $dayKey failed', error, stackTrace);
      }
      final rows = written ? await _readDayOr(day, fetched.value!) : fetched.value!;
      yield SwrSnapshot(data: rows, fetchedAt: now);
    } on ApiFailure catch (failure) {
      if (cached == null) rethrow;
      yield SwrSnapshot(data: cached, fetchedAt: window!.fetchedAt, failure: failure);
    } catch (error, stackTrace) {
      // A write, a decode or a programming error: not an API failure, so it is logged and
      // the cached copy still stands rather than being replaced by an empty list.
      _log('revalidating $dayKey failed', error, stackTrace);
      const failure = ApiFailure();
      if (cached == null) throw failure;
      yield SwrSnapshot(data: cached, fetchedAt: window!.fetchedAt, failure: failure);
    }
  }

  /// `GET /v1/matches/{id}`, cached under `match:<id>`.
  Stream<SwrSnapshot<MatchDetail>> watchMatchDetail(int matchId) => _document<MatchDetail>(
        key: DocumentKeys.matchDetail(matchId),
        fetch: (etag) => _conditional<MatchDetail, EnvelopeMatchDetail>(
          etag: etag,
          send: (client) => client.getMatchV1MatchesMatchIdGet(matchId: matchId),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: (json) => MatchDetail.fromJson((json! as Map).cast<String, Object?>()),
        encode: (value) => value.toJson(),
      );

  /// `GET /v1/teams/{id}`, cached under `team:<id>`: S9's followed teams, so their names and
  /// competitions show without a match being cached for them, and S7's header.
  Stream<SwrSnapshot<TeamDetail>> watchTeamDetail(int teamId) => _document<TeamDetail>(
        key: DocumentKeys.team(teamId),
        fetch: (etag) => _conditional<TeamDetail, EnvelopeTeamDetail>(
          etag: etag,
          send: (client) => client.getTeamV1TeamsTeamIdGet(teamId: teamId),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: (json) => TeamDetail.fromJson((json! as Map).cast<String, Object?>()),
        encode: (value) => value.toJson(),
      );

  /// `GET /v1/channels/{id}`, cached under `channel:<id>`: S6's sheet.
  Stream<SwrSnapshot<ChannelDetail>> watchChannelDetail(int channelId) =>
      _document<ChannelDetail>(
        key: DocumentKeys.channel(channelId),
        fetch: (etag) => _conditional<ChannelDetail, EnvelopeChannelDetail>(
          etag: etag,
          send: (client) => client.getChannelV1ChannelsChannelIdGet(channelId: channelId),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: (json) => ChannelDetail.fromJson((json! as Map).cast<String, Object?>()),
        encode: (value) => value.toJson(),
      );

  /// `GET /v1/competitions/{id}`, cached under `competition:<id>`: S8's page.
  Stream<SwrSnapshot<CompetitionDetail>> watchCompetitionDetail(int competitionId) =>
      _document<CompetitionDetail>(
        key: DocumentKeys.competition(competitionId),
        fetch: (etag) => _conditional<CompetitionDetail, EnvelopeCompetitionDetail>(
          etag: etag,
          send: (client) =>
              client.getCompetitionV1CompetitionsCompetitionIdGet(competitionId: competitionId),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: (json) => CompetitionDetail.fromJson((json! as Map).cast<String, Object?>()),
        encode: (value) => value.toJson(),
      );

  /// `GET /v1/satellites`, cached under [DocumentKeys.satellites].
  Stream<SwrSnapshot<List<Satellite>>> watchSatellites() => _document<List<Satellite>>(
        key: DocumentKeys.satellites,
        fetch: (etag) => _conditional<List<Satellite>, EnvelopeListSatellite>(
          etag: etag,
          send: (client) => client.listSatellitesV1SatellitesGet(),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: _decodeList(Satellite.fromJson),
        encode: _encodeList,
      );

  /// `GET /v1/satellites/{id}/channels`, cached under
  /// [DocumentKeys.satelliteChannels].
  Stream<SwrSnapshot<List<ChannelCarriage>>> watchSatelliteChannels(int satelliteId) =>
      _document<List<ChannelCarriage>>(
        key: DocumentKeys.satelliteChannels(satelliteId),
        fetch: (etag) => _conditional<List<ChannelCarriage>, EnvelopeListChannelCarriage>(
          etag: etag,
          send: (client) =>
              client.listSatelliteChannelsV1SatellitesSatelliteIdChannelsGet(
            satelliteId: satelliteId,
          ),
          unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
        ),
        decode: _decodeList(ChannelCarriage.fromJson),
        encode: _encodeList,
      );

  /// S4's day: `GET /v1/matches?from&to&satellite_ids=…`, cached under
  /// [DocumentKeys.matchesBySatellites]. Never written to the `matches` table: it is a
  /// filtered answer, and S2's day must keep its own rows (R25).
  Stream<SwrSnapshot<List<MatchSummary>>> watchMatchesBySatellites({
    required DateTime day,
    required Set<int> satelliteIds,
  }) =>
      _document<List<MatchSummary>>(
        key: DocumentKeys.matchesBySatellites(day, satelliteIds),
        fetch: (etag) {
          final window = _db.dayWindow(day);
          return _conditional<List<MatchSummary>, EnvelopeListMatchSummary>(
            etag: etag,
            send: (client) => client.listMatchesV1MatchesGet(
              from: window.from.toUtc(),
              to: window.to.toUtc(),
              satelliteIds: _sortedIds(satelliteIds),
            ),
            unwrap: (envelope) => _dataOf(envelope.success, envelope.error, envelope.data),
          );
        },
        decode: _decodeList(MatchSummary.fromJson),
        encode: _encodeList,
      );

  /// The shared document path: emit the cached body, revalidate it, then emit the answer.
  /// [decode] runs on the cached body and [encode] writes the fresh one, so a body the
  /// current models cannot read is refetched instead of breaking the screen.
  Stream<SwrSnapshot<T>> _document<T>({
    required String key,
    required Future<_Fetched<T>> Function(String? etag) fetch,
    required T Function(Object? json) decode,
    required Object? Function(T value) encode,
  }) async* {
    var stored = await _db.documentFor(key);
    T? cached;
    if (stored != null) {
      try {
        cached = decode(jsonDecode(stored.body));
        yield SwrSnapshot(data: cached, fetchedAt: stored.fetchedAt);
      } catch (error, stackTrace) {
        _log('reading the cached document $key failed', error, stackTrace);
        stored = null;
      }
    }

    final fetched = await _guard(fetch, stored, cached);
    if (fetched.isFailure) {
      yield fetched.snapshot!;
      return;
    }
    final now = _db.now().toUtc();
    if (fetched.notModified) {
      await _db.touchDocument(key, now);
      yield SwrSnapshot(data: cached, fetchedAt: now);
      return;
    }
    // The fresh body still stands when the cache cannot take it.
    try {
      await _db.putDocument(
        key: key,
        etag: fetched.etag,
        body: jsonEncode(encode(fetched.value as T)),
        fetchedAt: now,
      );
    } catch (error, stackTrace) {
      _log('writing the document $key failed', error, stackTrace);
    }
    yield SwrSnapshot(data: fetched.value, fetchedAt: now);
  }

  /// The day as drift now holds it, or [fallback] when it cannot be read back.
  Future<List<MatchSummary>> _readDayOr(DateTime day, List<MatchSummary> fallback) async {
    try {
      return await _db.readDay(day);
    } catch (error, stackTrace) {
      _log('re-reading the day failed', error, stackTrace);
      return fallback;
    }
  }

  /// Runs [fetch], turning a failure into a snapshot that keeps [cached] when there is one
  /// and rethrows when there is not. A storage failure after a good `200` never discards
  /// the fresh body: the value is emitted and the write is logged (`_document`).
  Future<_Fetched<T>> _guard<T>(
    Future<_Fetched<T>> Function(String? etag) fetch,
    CachedDocument? stored,
    T? cached,
  ) async {
    try {
      return await fetch(stored?.etag);
    } on ApiFailure catch (failure) {
      if (cached == null) rethrow;
      return _Fetched.failed(
        SwrSnapshot(data: cached, fetchedAt: stored!.fetchedAt, failure: failure),
      );
    } catch (error, stackTrace) {
      _log('revalidating a document failed', error, stackTrace);
      if (cached == null) throw const ApiFailure();
      return _Fetched.failed(
        SwrSnapshot(data: cached, fetchedAt: stored!.fetchedAt, failure: const ApiFailure()),
      );
    }
  }

  /// One conditional GET through the generated client, with the drift ETag.
  Future<_Fetched<T>> _conditional<T, E extends Object>({
    required String? etag,
    required Future<HttpResponse<E>> Function(MadarApiClient client) send,
    required T? Function(E envelope) unwrap,
  }) async {
    final client = MadarApi(_requestDio(etag)).madarApi;
    try {
      final response = await send(client);
      // A `304` an interceptor turned into a response (`EtagInterceptor` does, and the
      // request carries the app's interceptors) is still "not modified" (M-R2-5).
      if (response.response.statusCode == 304) return _Fetched<T>.notModified();
      final value = unwrap(response.data);
      if (value == null) throw const ApiFailure();
      return _Fetched.changed(
        etag: response.response.headers.value('etag'),
        value: value,
      );
    } on DioException catch (error) {
      if (error.isNotModified) return _Fetched<T>.notModified();
      throw error.asApiFailure;
    }
  }

  /// A request-scoped view of the app's Dio: its base options, adapter and transformer, and
  /// every interceptor `dioProvider` carries at request time except [EtagInterceptor], plus
  /// the one drift ETag this request sends (M-R2-5).
  ///
  /// The app's Dio cannot be used as it stands: the ETag comes from drift, not from
  /// `EtagInterceptor`'s memory, and the generated client offers nowhere to set an extra on
  /// a single request. Copying the interceptors, rather than building a bare Dio, is what
  /// keeps a later addition to `dioProvider` (D3's `Authorization: Device` token, a log)
  /// reaching these reads too.
  Dio _requestDio(String? etag) {
    final base = _dio.options;
    return Dio(
      BaseOptions(
        baseUrl: base.baseUrl,
        connectTimeout: base.connectTimeout,
        receiveTimeout: base.receiveTimeout,
        sendTimeout: base.sendTimeout,
        headers: base.headers,
        responseType: base.responseType,
        contentType: base.contentType,
        followRedirects: base.followRedirects,
        validateStatus: base.validateStatus,
      ),
    )
      ..httpClientAdapter = _dio.httpClientAdapter
      ..transformer = _dio.transformer
      ..interceptors.addAll(
        _dio.interceptors.where((interceptor) => interceptor is! EtagInterceptor),
      )
      ..interceptors.add(_ConditionalEtag(etag));
  }

  static T? _dataOf<T>(bool success, ErrorBody? error, T? data) {
    if (!success) throw ApiFailure(code: error?.code);
    return data;
  }

  static List<T> Function(Object?) _decodeList<T>(T Function(Map<String, Object?>) fromJson) =>
      (json) => [
            for (final item in json! as List<Object?>)
              fromJson((item! as Map).cast<String, Object?>()),
          ];

  static Object? _encodeList(Object? value) => [
        for (final item in value! as List<Object?>)
          (item! as dynamic).toJson(),
      ];

  static String _sortedIds(Set<int> ids) => (ids.toList()..sort()).join(',');

  static void _log(String message, Object error, StackTrace stackTrace) => developer.log(
        message,
        name: 'madar.swr',
        error: error,
        stackTrace: stackTrace,
      );
}

/// The one `If-None-Match` a request carries, so concurrent screens never share one.
class _ConditionalEtag extends Interceptor {
  _ConditionalEtag(this.etag);

  final String? etag;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (etag != null) options.headers['If-None-Match'] = etag;
    handler.next(options);
  }
}

/// What a conditional GET produced.
class _Fetched<T> {
  const _Fetched.notModified()
      : notModified = true,
        etag = null,
        value = null,
        snapshot = null;

  const _Fetched.changed({required this.etag, required T this.value})
      : notModified = false,
        snapshot = null;

  const _Fetched.failed(SwrSnapshot<T> this.snapshot)
      : notModified = false,
        etag = null,
        value = null;

  final bool notModified;
  final String? etag;
  final T? value;

  /// Only set by [_Fetched.failed]: the cached copy with its failure.
  final SwrSnapshot<T>? snapshot;

  bool get isFailure => snapshot != null;
}
