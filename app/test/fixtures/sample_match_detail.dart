import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:madar_sat/core/network/generated/export.dart';

import 'fake_http_adapter.dart';
import 'sample_models.dart';

/// Satellites other than [sampleSatellite] (Nilesat 7.0W, one of "my satellites").
const badrSatellite = SatelliteRef(
  id: 5,
  slug: 'badr-26-0e',
  nameAr: 'بدر',
  nameEn: 'Badr 26.0E',
  orbitalPosition: 26,
);

const hotbirdSatellite = SatelliteRef(
  id: 7,
  slug: 'hotbird-13-0e',
  nameAr: 'هوت بيرد',
  nameEn: 'Hotbird 13.0E',
  orbitalPosition: 13,
);

const eutelSatellite = SatelliteRef(
  id: 8,
  slug: 'eutel-16-0e',
  nameAr: 'يوتل 16',
  nameEn: 'Eutel 16.0E',
  orbitalPosition: 16,
);

const sampleFrequency = Frequency(mhz: 11843, pol: Polarization.h, sr: 27500);

const sampleCommentator = CommentatorRef(
  id: 31,
  name: 'عصام الشوالي',
  image: null,
  audio: 'https://media.test/clips/shawali.mp3',
);

/// One carriage as `GET /v1/matches/{id}` lists it. [satellite] and [frequency] default to
/// Nilesat and `11843 H 27500`; pass null for a terrestrial link.
CarriageEntry sampleCarriageEntry({
  required int id,
  String? name,
  SatelliteRef? satellite = sampleSatellite,
  Access? access = Access.encrypted,
  Frequency? frequency = sampleFrequency,
  Kind kind = Kind.satellite,
  String? displayName,
  String? provider,
  String? frequencyNote,
  DateTime? changedAt,
  Category? category = Category.sports,
  String? country,
  List<CommentatorRef> commentators = const [],
}) =>
    CarriageEntry(
      id: id,
      kind: kind,
      name: name ?? 'Channel $id',
      displayName: displayName,
      logo: null,
      category: category,
      satellite: satellite,
      frequency: frequency,
      frequencyNote: frequencyNote,
      access: access,
      provider: provider,
      package: null,
      beam: Beam.wide,
      country: country,
      frequencyChangedAt: changedAt,
      commentators: commentators,
    );

PlatformGroup samplePlatformGroup(String region, List<String> names, {String? country}) =>
    PlatformGroup(
      region: region,
      items: [
        for (var i = 0; i < names.length; i++)
          PlatformEntry(channelId: 9000 + i, country: country, logo: null, name: names[i]),
      ],
    );

/// A manual broadcaster entry (`kind: custom`) as the admin types it.
BroadcastEntry sampleCustomBroadcast(
  String label, {
  Access? access,
  List<CommentatorRef> commentators = const [],
}) =>
    BroadcastEntry(
      kind: BroadcastEntryKind.custom,
      channelId: null,
      label: label,
      logo: null,
      access: access,
      satellite: null,
      frequency: null,
      commentators: commentators,
    );

/// `GET /v1/matches/{id}` as a model. Built the way [sampleMatch] is, from local wall-clock
/// times, so it reads the same under every host zone.
MatchDetail sampleMatchDetail({
  int id = 48213,
  Status status = Status.scheduled,
  bool estimated = false,
  bool timeTbd = false,
  DateTime? kickoff,
  Score? score,
  String? minute,
  Sport sport = Sport.football,
  String home = 'الأهلي',
  String away = 'الزمالك',
  List<CarriageEntry> carriages = const [],
  List<PlatformGroup> platforms = const [],
  List<BroadcastEntry> broadcasts = const [],
  String? stadium,
  String? localBroadcasterEg,
  CommentatorRef? commentator,
}) {
  final kickoffAt = kickoff ?? sampleKickoffAt();
  return MatchDetail(
    id: id,
    sport: sport,
    kickoffAt: timeTbd ? null : kickoffAt,
    timeTbd: timeTbd,
    matchDate: DateTime(2026, 10, 28),
    status: status,
    estimated: estimated,
    period: null,
    minute: minute,
    score: score,
    statusLabel: null,
    competition: const CompetitionRef(
      id: 12,
      logo: null,
      name: 'الدوري المصري الممتاز',
      priority: 3,
      stage: 'الجولة 9',
    ),
    home: TeamRef(id: 1, logo: null, name: home),
    away: TeamRef(id: 2, logo: null, name: away),
    broadcast: Broadcast(
      channelCount: carriages.length,
      hasFree: carriages.any((c) => c.access == Access.free),
      headline: const [],
    ),
    commentator: commentator,
    updatedAt: DateTime.utc(2026, 10, 28, 17, 59),
    broadcasts: broadcasts,
    carriages: carriages,
    platforms: platforms,
    stadium: stadium,
    localBroadcasterEg: localBroadcasterEg,
    events: const [],
    lineups: null,
    feedId: null,
  );
}

/// The envelope's `data` for [detail]: the map shape the generated client parses, with
/// `match_date` as the date string the API sends (never a hand-made UTC midnight).
Map<String, Object?> matchDetailJson(MatchDetail detail) {
  final json = jsonDecode(jsonEncode(detail)) as Map<String, Object?>;
  json['match_date'] = '2026-10-28';
  return json;
}

/// A catalogue satellite; [receptionUrl] is the video S3 opens for its carriages.
Satellite sampleSatelliteEntry(
  SatelliteRef ref, {
  String? receptionUrl,
}) =>
    Satellite(
      id: ref.id,
      slug: ref.slug,
      kind: Kind.satellite,
      nameAr: ref.nameAr,
      nameEn: ref.nameEn,
      orbitalPosition: ref.orbitalPosition,
      logo: null,
      channelCount: 12,
      bestFrequency: null,
      worstFrequency: null,
      receptionUrl: receptionUrl,
    );

List<Object?> satellitesJson(List<Satellite> satellites) =>
    jsonDecode(jsonEncode(satellites)) as List<Object?>;

/// `FakeHttpAdapter` answers in the order requests arrive, and S3 asks for the match and the
/// satellite list at about the same time. This answers by path instead: queue the answers
/// for each path, and each request takes the next one for its own path.
///
/// A path with nothing queued answers as an unreachable network, so an unexpected request
/// shows up as an offline failure (and in [requestsTo]) rather than hanging.
class RoutedApi {
  RoutedApi() {
    for (var i = 0; i < _slots; i++) {
      adapter.enqueue(_dispatch);
    }
  }

  static const int _slots = 80;

  final FakeHttpAdapter adapter = FakeHttpAdapter();
  final Map<String, List<FutureOr<ResponseBody> Function(RequestOptions)>> _routes = {};

  /// A Dio on [adapter] that parses on the calling isolate: the default transformer decodes a
  /// large body on a background isolate, which a widget test's fake clock never finishes.
  Dio get dio => Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter
    ..transformer = SyncTransformer();

  void answer(String path, Object? data, {String? etag}) =>
      respond(path, (_) => FakeHttpAdapter.envelope(data, etag: etag));

  void notModified(String path, {String? etag}) =>
      respond(path, (_) => FakeHttpAdapter.notModified(etag: etag));

  void offline(String path) => respond(
        path,
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
        ),
      );

  void failWith(String path, String code, {int status = 404}) => respond(
        path,
        (_) => ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {'code': code, 'message': 'for logs only'},
            'meta': <String, Object?>{},
          }),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

  /// The requests that reached [path], oldest first.
  List<RequestOptions> requestsTo(String path) =>
      adapter.requests.where((r) => r.path == path).toList(growable: false);

  /// Queues an arbitrary answer for [path], for a test that holds a response back.
  void respond(String path, FutureOr<ResponseBody> Function(RequestOptions) handler) =>
      _routes.putIfAbsent(path, () => []).add(handler);

  FutureOr<ResponseBody> _dispatch(RequestOptions options) {
    final queue = _routes[options.path];
    if (queue == null || queue.isEmpty) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'nothing queued for ${options.path}',
      );
    }
    return queue.removeAt(0)(options);
  }
}
