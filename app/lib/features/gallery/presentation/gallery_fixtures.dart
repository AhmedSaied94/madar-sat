import '../../../core/network/generated/export.dart';

/// Sample rows for the debug gallery only. Not product data: no real fixture is bundled.
abstract final class GalleryFixtures {
  static const _teamHome = TeamRef(id: 1, logo: null, name: 'الأهلي');
  static const _teamAway = TeamRef(id: 2, logo: null, name: 'الزمالك');
  static const _competition = CompetitionRef(
    id: 12,
    logo: null,
    name: 'الدوري المصري الممتاز',
    priority: 3,
    stage: 'الجولة 9',
  );
  static const _nilesat = SatelliteRef(
    id: 2,
    slug: 'nilesat-7-0w',
    nameAr: 'نايل سات',
    nameEn: 'Nilesat 7.0W',
    orbitalPosition: -7,
  );
  static const _frequency = Frequency(mhz: 11843, pol: Polarization.h, sr: 27500);
  static const _headline = HeadlineEntry(
    access: Access.free,
    channelId: 5512,
    frequency: _frequency,
    name: 'ON Sport 1',
    satellite: _nilesat,
  );

  static MatchSummary match({
    Status status = Status.scheduled,
    bool estimated = false,
    DateTime? kickoff,
    bool timeTbd = false,
    Score? score,
    String? minute,
    Sport sport = Sport.football,
    bool withChannels = true,
    String home = 'الأهلي',
    String away = 'الزمالك',
  }) {
    return MatchSummary(
      id: 48213,
      sport: sport,
      kickoffAt: kickoff,
      timeTbd: timeTbd,
      matchDate: DateTime(2026, 10, 28),
      status: status,
      estimated: estimated,
      period: null,
      minute: minute,
      score: score,
      statusLabel: null,
      competition: _competition,
      home: TeamRef(id: 1, logo: null, name: home),
      away: TeamRef(id: 2, logo: null, name: away),
      broadcast: Broadcast(
        channelCount: withChannels ? 14 : 0,
        hasFree: withChannels,
        headline: withChannels ? const [_headline] : const [],
      ),
      commentator: null,
      updatedAt: DateTime.utc(2026, 10, 28, 17, 59),
    );
  }

  static ChannelCarriage carriage({
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
      satellite: withSatellite ? _nilesat : null,
      frequency: withSatellite ? _frequency : null,
      frequencyNote: withSatellite ? null : 'UHF 32',
      access: access,
      provider: null,
      package: null,
      beam: Beam.wide,
      country: null,
      frequencyChangedAt: DateTime.utc(2026, 10, 20),
    );
  }

  static final List<DateTime> week = [
    DateTime(2026, 10, 26),
    DateTime(2026, 10, 27),
    DateTime(2026, 10, 28),
    DateTime(2026, 10, 29),
    DateTime(2026, 10, 30),
    DateTime(2026, 10, 31),
    DateTime(2026, 11, 1),
  ];

  static const home = _teamHome;
  static const away = _teamAway;
  static const nilesat = _nilesat;
  static const frequency = _frequency;
}
