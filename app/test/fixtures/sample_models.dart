import 'dart:convert';

import 'package:madar_sat/core/network/generated/export.dart';

/// A fixed instant whose wall clock reads 18:00 on the device (research R18).
///
/// Fixtures and goldens are built from local wall-clock times, never from a fixed UTC
/// instant: the widgets render local time, so a UTC fixture would draw a different PNG in
/// every host zone and fail in the UTC container the goldens are generated in.
DateTime sampleNow({int hour = 18, int minute = 0}) => DateTime(2026, 10, 28, hour, minute);

/// A kickoff whose local wall clock reads [hour]:[minute], as the UTC instant the API sends.
DateTime sampleKickoffAt({int hour = 21, int minute = 0}) =>
    sampleNow(hour: hour, minute: minute).toUtc();

/// A `MatchSummary` built the way the app really receives one: a JSON map off the wire, so
/// `match_date` is a date string that `MatchSummary.fromJson` parses to local midnight
/// (M-R2-1). A fixture made by hand with `DateTime.utc(...)` would hide a zone bug.
MatchSummary sampleMatchFromJson({
  String matchDate = '2026-10-28',
  String status = 'scheduled',
  bool nullKickoff = false,
}) {
  // `toJson` leaves the nested parts as models, so round-trip through the encoder: this is
  // the map shape the generated client parses.
  final json = jsonDecode(jsonEncode(sampleMatch().toJson())) as Map<String, Object?>;
  json['match_date'] = matchDate;
  json['status'] = status;
  if (nullKickoff) {
    json['kickoff_at'] = null;
    json['time_tbd'] = true;
  }
  return MatchSummary.fromJson(json);
}

/// Sample models for widget and golden tests. Synthetic, never the real snapshot.
MatchSummary sampleMatch({
  int id = 48213,
  Status status = Status.scheduled,
  bool estimated = false,
  bool timeTbd = false,
  DateTime? kickoff,
  Score? score,
  String? minute,
  Sport sport = Sport.football,
  bool withChannels = true,
  String home = 'الأهلي',
  String away = 'الزمالك',
}) {
  final kickoffAt = kickoff ?? sampleKickoffAt();
  return MatchSummary(
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
      channelCount: withChannels ? 14 : 0,
      hasFree: withChannels,
      headline: withChannels
          ? [
              const HeadlineEntry(
                access: Access.free,
                channelId: 5512,
                frequency: Frequency(mhz: 11843, pol: Polarization.h, sr: 27500),
                name: 'ON Sport 1',
                satellite: sampleSatellite,
              ),
            ]
          : const [],
    ),
    commentator: null,
    updatedAt: DateTime.utc(2026, 10, 28, 17, 59),
  );
}

const sampleSatellite = SatelliteRef(
  id: 2,
  slug: 'nilesat-7-0w',
  nameAr: 'نايل سات',
  nameEn: 'Nilesat 7.0W',
  orbitalPosition: -7,
);

ChannelCarriage sampleCarriage({
  bool withSatellite = true,
  Access access = Access.encrypted,
}) {
  return ChannelCarriage(
    id: 5512,
    kind: Kind.satellite,
    name: 'beIN SPORTS 1 HD',
    displayName: 'beIN SPORTS 1',
    logo: null,
    category: Category.sports,
    satellite: withSatellite ? sampleSatellite : null,
    frequency: withSatellite
        ? const Frequency(mhz: 11843, pol: Polarization.h, sr: 27500)
        : null,
    frequencyNote: withSatellite ? null : 'UHF 32',
    access: access,
    provider: null,
    package: null,
    beam: Beam.wide,
    country: null,
    frequencyChangedAt: DateTime.utc(2026, 10, 20),
  );
}
