import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:madar_sat/core/network/generated/export.dart';

import 'fake_http_adapter.dart';
import 'sample_models.dart';

/// Builders and wire helpers for the S4 (My satellites) and S5 (Frequencies) tests.
///
/// Everything is synthetic. Kickoffs are built from local wall-clock times
/// ([sampleKickoffAt]), never from a fixed UTC instant, so the tests read the same in every
/// host zone.

/// The default "my satellites" (O10): Nilesat 7.0W and Badr 26.0E, found by slug.
const nilesatRef = sampleSatellite;

const badrRef = SatelliteRef(
  id: 5,
  slug: 'badr-26-0e',
  nameAr: 'بدر',
  nameEn: 'Badr 26.0E',
  orbitalPosition: 26,
);

const hotbirdRef = SatelliteRef(
  id: 7,
  slug: 'hotbird-13-0e',
  nameAr: 'هوت بيرد',
  nameEn: 'Hotbird 13.0E',
  orbitalPosition: 13,
);

/// One `/v1/satellites` entry.
Satellite satelliteEntry(
  SatelliteRef ref, {
  int channelCount = 63,
  Kind kind = Kind.satellite,
  Frequency? best,
  Frequency? worst,
  String? receptionUrl,
}) =>
    Satellite(
      id: ref.id,
      slug: ref.slug,
      kind: kind,
      nameAr: ref.nameAr,
      nameEn: ref.nameEn,
      orbitalPosition: ref.orbitalPosition,
      logo: null,
      channelCount: channelCount,
      bestFrequency: best,
      worstFrequency: worst,
      receptionUrl: receptionUrl,
    );

/// The three satellites most tests start from, in the server's order (admin priority).
List<Satellite> sampleSatellites() => [
      satelliteEntry(
        hotbirdRef,
        channelCount: 189,
      ),
      satelliteEntry(
        nilesatRef,
        channelCount: 63,
        best: const Frequency(mhz: 12054, pol: Polarization.v, sr: 27500),
        worst: const Frequency(mhz: 11373, pol: Polarization.h, sr: 27500),
        receptionUrl: 'https://www.youtube.com/watch?v=nilesat-reception',
      ),
      satelliteEntry(badrRef, channelCount: 69),
    ];

/// One `/v1/satellites/{id}/channels` entry.
ChannelCarriage channelEntry({
  required int id,
  required String name,
  String? displayName,
  Category? category = Category.sports,
  Access access = Access.encrypted,
  SatelliteRef? satellite = nilesatRef,
  int? mhz = 11013,
  Polarization pol = Polarization.h,
  int sr = 27500,
  String? provider,
  String? package,
  String? frequencyNote,
  DateTime? changedAt,
}) =>
    ChannelCarriage(
      id: id,
      kind: Kind.satellite,
      name: name,
      displayName: displayName,
      logo: null,
      category: category,
      satellite: satellite,
      frequency: mhz == null ? null : Frequency(mhz: mhz, pol: pol, sr: sr),
      frequencyNote: frequencyNote,
      access: access,
      provider: provider,
      package: package,
      beam: Beam.wide,
      country: null,
      frequencyChangedAt: changedAt,
    );

/// A channel line on a match: what the server puts in `broadcast.headline`.
HeadlineEntry headlineEntry({
  required int channelId,
  required String name,
  SatelliteRef? satellite = nilesatRef,
  int? mhz = 11013,
  Polarization pol = Polarization.h,
  int sr = 27500,
  Access access = Access.encrypted,
}) =>
    HeadlineEntry(
      access: access,
      channelId: channelId,
      frequency: mhz == null ? null : Frequency(mhz: mhz, pol: pol, sr: sr),
      name: name,
      satellite: satellite,
    );

/// A match as `/v1/matches?satellite_ids=…` returns it: its competition, its status and the
/// carriages on the asked satellites.
MatchSummary satelliteMatch({
  required int id,
  int competitionId = 12,
  String competition = 'الدوري المصري الممتاز',
  int? priority = 3,
  String? stage = 'الجولة 8',
  Status status = Status.scheduled,
  int hour = 21,
  int minute = 0,
  String home = 'الأهلي',
  String away = 'الزمالك',
  Score? score,
  String? matchMinute,
  List<HeadlineEntry> headline = const [],
}) =>
    sampleMatch(
      id: id,
      status: status,
      kickoff: sampleKickoffAt(hour: hour, minute: minute),
      score: score,
      minute: matchMinute,
      home: home,
      away: away,
    ).copyWith(
      competition: CompetitionRef(
        id: competitionId,
        logo: null,
        name: competition,
        priority: priority,
        stage: stage,
      ),
      broadcast: Broadcast(
        channelCount: headline.length,
        hasFree: headline.any((entry) => entry.access == Access.free),
        headline: headline,
      ),
    );

/// A model as the server sends it: the map the generated `fromJson` reads.
Map<String, Object?> wire(Object model) =>
    jsonDecode(jsonEncode(model)) as Map<String, Object?>;

/// A match on the wire, with `match_date` as the date string the API sends.
Map<String, Object?> matchWire(MatchSummary match) =>
    wire(match)..['match_date'] = '2026-10-28';

List<Object?> matchesWire(Iterable<MatchSummary> matches) => [
      for (final match in matches) matchWire(match),
    ];

List<Object?> satellitesWire(Iterable<Satellite> satellites) => [
      for (final satellite in satellites) wire(satellite),
    ];

List<Object?> channelsWire(Iterable<ChannelCarriage> channels) => [
      for (final channel in channels) wire(channel),
    ];

/// A transport failure for [options]: no connection.
ResponseBody offlineResponse(RequestOptions options) => throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'offline',
    );

/// A [FakeHttpAdapter] answering by path, so a screen that asks for several documents in
/// any order still gets the right one. Per path, answers are used in the order added and the
/// last one repeats.
class RoutedHttp {
  RoutedHttp(this.adapter) {
    // The adapter takes one scripted answer per request; the same router serves them all.
    for (var i = 0; i < _scriptLength; i++) {
      adapter.enqueue(_respond);
    }
  }

  static const int _scriptLength = 60;

  final FakeHttpAdapter adapter;
  final Map<String, List<FutureOr<ResponseBody> Function(RequestOptions)>> _routes = {};

  /// The recorded requests to [path], oldest first.
  List<RequestOptions> requestsTo(String path) =>
      [for (final request in adapter.requests) if (request.path == path) request];

  /// Answers [path] with [response], after the answers already added for it.
  void on(String path, FutureOr<ResponseBody> Function(RequestOptions options) response) =>
      (_routes[path] ??= []).add(response);

  /// A `200` with [data] in the API envelope.
  void data(String path, Object? data, {String? etag}) =>
      on(path, (_) => FakeHttpAdapter.envelope(data, etag: etag));

  /// A `304 Not Modified`.
  void notModified(String path) => on(path, (_) => FakeHttpAdapter.notModified());

  /// No connection.
  void offline(String path) => on(path, offlineResponse);

  FutureOr<ResponseBody> _respond(RequestOptions options) {
    final answers = _routes[options.path];
    if (answers == null || answers.isEmpty) {
      throw StateError('RoutedHttp: no answer for ${options.method} ${options.uri}');
    }
    final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
    return next(options);
  }
}
