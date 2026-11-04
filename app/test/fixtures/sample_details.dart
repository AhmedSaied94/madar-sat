import 'dart:convert';

import 'package:madar_sat/core/network/generated/export.dart';

import 'sample_models.dart';

/// S6's data as `GET /v1/channels/{id}` sends it: the beIN SPORTS 1 carriage on Nilesat, one
/// other carriage on Badr, and the upcoming matches the sheet lists.
ChannelDetail sampleChannelDetail({
  int id = 5512,
  String name = 'beIN SPORTS 1 HD',
  String? displayName = 'beIN SPORTS 1',
  SatelliteRef? satellite = sampleSatellite,
  Frequency? frequency = const Frequency(mhz: 11013, pol: Polarization.h, sr: 27500),
  String? frequencyNote,
  Access? access = Access.encrypted,
  String? provider = 'beIN',
  String? package = 'beIN Sports',
  Category? category = Category.sports,
  String? country = 'قطر',
  List<ChannelCarriage> otherCarriages = const [],
  List<MatchSummary> upcomingMatches = const [],
  List<FrequencyChange> recentFrequencyChanges = const [],
}) =>
    ChannelDetail(
      id: id,
      kind: Kind.satellite,
      name: name,
      displayName: displayName,
      logo: null,
      category: category,
      satellite: satellite,
      frequency: frequency,
      frequencyNote: frequencyNote,
      frequencyChangedAt: null,
      beam: Beam.wide,
      access: access,
      provider: provider,
      package: package,
      country: country,
      otherCarriages: otherCarriages,
      upcomingMatches: upcomingMatches,
      recentFrequencyChanges: recentFrequencyChanges,
    );

/// A carriage on another satellite, as `other_carriages` lists it.
ChannelCarriage sampleOtherCarriage({
  required int id,
  String? name,
  SatelliteRef? satellite,
  bool withSatellite = true,
  Access? access = Access.encrypted,
  Frequency? frequency = const Frequency(mhz: 10810, pol: Polarization.h, sr: 27500),
  String? provider,
  String? package,
}) =>
    ChannelCarriage(
      id: id,
      kind: Kind.satellite,
      name: name ?? 'Channel $id',
      displayName: null,
      logo: null,
      category: Category.sports,
      satellite: withSatellite ? satellite ?? sampleSatellite : null,
      frequency: frequency,
      frequencyNote: null,
      access: access,
      provider: provider,
      package: package,
      beam: Beam.wide,
      country: null,
      frequencyChangedAt: null,
    );

/// A channel's detail as the envelope's `data`: the map the generated client parses.
Map<String, Object?> channelDetailJson(ChannelDetail detail) =>
    jsonDecode(jsonEncode(detail.toJson())) as Map<String, Object?>;

/// S7's data as `GET /v1/teams/{id}` sends it.
TeamDetail sampleTeamDetail({
  int id = 1,
  String name = 'الأهلي',
  String? stadium = 'استاد القاهرة الدولي',
  Sport sport = Sport.football,
  String? country = 'مصر',
  List<NamedRef> competitions = const [],
  PrimaryCompetitionRef? primaryCompetition = const PrimaryCompetitionRef(
    id: 12,
    name: 'الدوري المصري الممتاز',
  ),
  List<MatchSummary> upcoming = const [],
  List<MatchSummary> recent = const [],
}) =>
    TeamDetail(
      id: id,
      sport: sport,
      name: name,
      country: country,
      logo: null,
      stadium: stadium,
      competitions: competitions,
      primaryCompetition: primaryCompetition,
      upcoming: upcoming,
      recent: recent,
    );

Map<String, Object?> teamDetailJson(TeamDetail detail) =>
    jsonDecode(jsonEncode(detail.toJson())) as Map<String, Object?>;

/// S8's data as `GET /v1/competitions/{id}` sends it, today's shape: the rights holders are
/// names only until B1's D5 contract adds their satellites (T017).
CompetitionDetail sampleCompetitionDetail({
  int id = 12,
  String name = 'الدوري المصري الممتاز',
  int? priority = 1,
  Sport sport = Sport.football,
  List<MatchSummary> upcoming = const [],
  List<MatchSummary> recent = const [],
  List<RightsHolderRef> rightsHolders = const [],
}) =>
    CompetitionDetail(
      id: id,
      sport: sport,
      name: name,
      logo: null,
      priority: priority,
      upcoming: upcoming,
      recent: recent,
      rightsHolders: rightsHolders,
    );

/// A rights holder on S8: a name, the satellites it airs on, and how many competitions it
/// carries.
RightsHolderRef sampleRightsHolder({
  required int id,
  String name = 'beIN Sports',
  List<SatelliteRef> satellites = const [],
  int competitionCount = 9,
}) =>
    RightsHolderRef(
      id: id,
      name: name,
      logo: null,
      satellites: satellites,
      competitionCount: competitionCount,
    );

Map<String, Object?> competitionDetailJson(CompetitionDetail detail) =>
    jsonDecode(jsonEncode(detail.toJson())) as Map<String, Object?>;

/// A match as a channel's `upcoming_matches` or a team's `upcoming`/`recent` lists it.
MatchSummary sampleTeamMatch({
  required int id,
  DateTime? kickoff,
  String home = 'مودرن سبورت',
  String away = 'الأهلي',
  Status status = Status.scheduled,
  Score? score,
  bool estimated = false,
  bool withChannels = true,
  bool timeTbd = false,
}) {
  final base = sampleMatch(
    id: id,
    kickoff: kickoff,
    status: status,
    score: score,
    estimated: estimated,
    timeTbd: timeTbd,
    withChannels: withChannels,
    home: home,
    away: away,
  );
  return base;
}

/// One `recent_frequency_changes` row, as the contract sends it.
FrequencyChange sampleFrequencyChange({
  required String detectedAt,
  required int from,
  required int to,
  String polarization = 'H',
  int symbolRate = 27500,
}) =>
    FrequencyChange.fromJson(
      frequencyChangeJson(
        detectedAt: detectedAt,
        from: from,
        to: to,
        polarization: polarization,
        symbolRate: symbolRate,
      ),
    );

/// A frequency history row in the shape `recent_frequency_changes` documents.
Map<String, Object?> frequencyChangeJson({
  required String detectedAt,
  int? from,
  int? to,
  String polarization = 'H',
  int symbolRate = 27500,
}) =>
    {
      'old': from == null
          ? null
          : {'frequency_mhz': from, 'polarization': polarization, 'symbol_rate': symbolRate},
      'new': to == null
          ? null
          : {'frequency_mhz': to, 'polarization': polarization, 'symbol_rate': symbolRate},
      'detected_at': detectedAt,
    };
