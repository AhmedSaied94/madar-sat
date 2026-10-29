import 'package:madar_sat/core/network/generated/export.dart';

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
  final kickoffAt = kickoff ?? DateTime.utc(2026, 10, 28, 18);
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
