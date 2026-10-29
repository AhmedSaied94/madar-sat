import 'package:flutter/material.dart';

import '../../../core/network/generated/export.dart';
import '../../../core/theme/madar_theme.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/badges.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/carriage_row.dart';
import '../../../design/components/date_strip.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/frequency_readout.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/match_row.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/status_block.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import 'gallery_fixtures.dart';

/// The debug-only component gallery (FR-043, FR-045): every signature component in its
/// states, with theme and text-scale toggles. Release builds have no `/gallery` route.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  Brightness _brightness = Brightness.dark;
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    return Theme(
      data: _brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(_scale)),
        child: Builder(
          builder: (context) {
            final colors = context.madarColors;
            return Scaffold(
              backgroundColor: colors.bg,
              body: SafeArea(
                child: Column(
                  children: [
                    MadarTopBar.detail(title: l.gallery),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: MadarSpace.s4,
                          vertical: MadarSpace.s3,
                        ),
                        children: [
                          _Toggles(
                            brightness: _brightness,
                            scale: _scale,
                            onBrightness: (value) => setState(() => _brightness = value),
                            onScale: (value) => setState(() => _scale = value),
                          ),
                          const _Section(title: 'Logo', children: [_LogoStates()]),
                          const _Section(title: 'StatusBlock', children: [_StatusStates()]),
                          const _Section(title: 'MatchRow', children: [_MatchRowStates()]),
                          const _Section(
                            title: 'FrequencyReadout',
                            children: [_FrequencyStates()],
                          ),
                          const _Section(title: 'CarriageRow', children: [_CarriageStates()]),
                          const _Section(title: 'Badges', children: [_BadgeStates()]),
                          const _Section(title: 'DateStrip', children: [_DateStripStates()]),
                          const _Section(title: 'MadarTopBar', children: [_TopBarStates()]),
                          const _Section(title: 'EmptyState', children: [_EmptyStates()]),
                          const _Section(title: 'Skeleton', children: [Skeleton()]),
                          const _Section(title: 'MadarBottomNav', children: [_NavStates()]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Toggles extends StatelessWidget {
  const _Toggles({
    required this.brightness,
    required this.scale,
    required this.onBrightness,
    required this.onScale,
  });

  final Brightness brightness;
  final double scale;
  final ValueChanged<Brightness> onBrightness;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MadarSpace.s2,
      runSpacing: MadarSpace.s1,
      children: [
        SegmentedButton<Brightness>(
          segments: [
            ButtonSegment(
              value: Brightness.dark,
              label: Text(AppLocalizations.of(context).themeDark),
            ),
            ButtonSegment(
              value: Brightness.light,
              label: Text(AppLocalizations.of(context).themeLight),
            ),
          ],
          selected: {brightness},
          onSelectionChanged: (value) => onBrightness(value.first),
        ),
        SegmentedButton<double>(
          segments: [
            const ButtonSegment(value: 1, label: Text('1.0×')),
            const ButtonSegment(value: 1.3, label: Text('1.3×')),
          ],
          selected: {scale},
          onSelectionChanged: (value) => onScale(value.first),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: MadarText.textMicro.copyWith(color: colors.textTertiary)),
          const SizedBox(height: MadarSpace.s2),
          ...children,
        ],
      ),
    );
  }
}

class _LogoStates extends StatelessWidget {
  const _LogoStates();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: MadarSpace.s3,
      runSpacing: MadarSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const BrandMark(size: BrandMarkSize.s28),
        const BrandMark(size: BrandMarkSize.m40),
        const BrandMark(size: BrandMarkSize.l64),
        const BrandMark(size: BrandMarkSize.m40, tone: BrandMarkTone.bare),
        const BrandMark(size: BrandMarkSize.m40, tone: BrandMarkTone.mono),
        MadarWordmark(wordmark: l.brandMark),
        const TeamCrest(name: 'الأهلي'),
        const LogoTile(kind: LogoTileKind.competition),
        const LogoTile(kind: LogoTileKind.channel, fallbackText: 'ON Sport'),
        const LogoTile(kind: LogoTileKind.satellite),
        const LogoTile(kind: LogoTileKind.commentator, fallbackText: 'عماد'),
      ],
    );
  }
}

class _StatusStates extends StatelessWidget {
  const _StatusStates();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.utc(2026, 10, 28, 18);
    final kickoff = DateTime.utc(2026, 10, 28, 18, 30);
    const score = Score(home: 1, away: 0, homePen: null, awayPen: null);
    return Wrap(
      spacing: MadarSpace.s4,
      runSpacing: MadarSpace.s3,
      children: [
        StatusBlock(status: Status.scheduled, kickoff: kickoff, now: now),
        StatusBlock(status: Status.scheduled, kickoff: kickoff, use24h: true, now: now),
        StatusBlock(
          status: Status.scheduled,
          kickoff: now.add(const Duration(minutes: 25)),
          now: now,
        ),
        const StatusBlock(status: Status.live, score: score, minute: '67', estimated: true),
        const StatusBlock(status: Status.live, score: score, minute: '45+2'),
        const StatusBlock(status: Status.halftime, score: score),
        const StatusBlock(status: Status.extraTime, score: score, minute: '105'),
        const StatusBlock(
          status: Status.penalties,
          score: Score(home: 2, away: 2, homePen: 3, awayPen: 4),
        ),
        const StatusBlock(status: Status.finished, score: score),
        const StatusBlock(status: Status.postponed),
        const StatusBlock(status: Status.cancelled),
        const StatusBlock(status: Status.abandoned),
        const StatusBlock(status: Status.scheduled, timeTbd: true),
      ],
    );
  }
}

class _MatchRowStates extends StatelessWidget {
  const _MatchRowStates();

  @override
  Widget build(BuildContext context) {
    final kickoff = DateTime.utc(2026, 10, 28, 18);
    const score = Score(home: 1, away: 0, homePen: null, awayPen: null);
    return Column(
      children: [
        MatchRow(match: GalleryFixtures.match(kickoff: kickoff)),
        MatchRow(
          match: GalleryFixtures.match(status: Status.live, score: score, minute: '67'),
        ),
        MatchRow(
          match: GalleryFixtures.match(status: Status.live, estimated: true),
        ),
        MatchRow(
          match: GalleryFixtures.match(status: Status.finished, score: score),
        ),
        MatchRow(match: GalleryFixtures.match(kickoff: kickoff, withChannels: false)),
        MatchRow(
          match: GalleryFixtures.match(
            kickoff: kickoff,
            sport: Sport.tennis,
            home: 'نوفاك ديوكوفيتش',
            away: 'كارلوس ألكاراز',
          ),
        ),
        MatchRow(
          match: GalleryFixtures.match(
            kickoff: kickoff,
            home: 'المقاولون العرب الرياضي',
            away: 'الاتحاد السكندري',
          ),
          followed: true,
          reminder: true,
        ),
      ],
    );
  }
}

class _FrequencyStates extends StatelessWidget {
  const _FrequencyStates();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: MadarSpace.s3,
      runSpacing: MadarSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FrequencyReadout(mhz: 11843, polarization: Polarization.h, symbolRate: 27500),
        FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
          size: FrequencyReadoutSize.lg,
        ),
        FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
          size: FrequencyReadoutSize.xl,
        ),
        FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
          state: FrequencyReadoutState.dim,
        ),
        FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
          state: FrequencyReadoutState.good,
        ),
        FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
          state: FrequencyReadoutState.bad,
        ),
        FrequencyReadout(note: 'UHF 32', state: FrequencyReadoutState.note),
      ],
    );
  }
}

class _CarriageStates extends StatelessWidget {
  const _CarriageStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarriageRow(carriage: GalleryFixtures.carriage()),
        CarriageRow(carriage: GalleryFixtures.carriage(), expanded: true),
        CarriageRow(carriage: GalleryFixtures.carriage(access: Access.free)),
        CarriageRow(carriage: GalleryFixtures.carriage(withSatellite: false)),
      ],
    );
  }
}

class _BadgeStates extends StatelessWidget {
  const _BadgeStates();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MadarSpace.s2,
      runSpacing: MadarSpace.s1,
      children: [
        const AccessBadge(access: Access.free),
        const AccessBadge(access: Access.encrypted),
        const AccessBadge(access: Access.encrypted, provider: 'beIN'),
        const SatelliteBadge(name: 'نايل سات'),
        ChangedBadge(changedAt: DateTime.utc(2026, 10, 20)),
        const CategoryBadge(sports: true),
        const CategoryBadge(sports: false),
        const CountBadge(count: 171),
      ],
    );
  }
}

class _DateStripStates extends StatelessWidget {
  const _DateStripStates();

  @override
  Widget build(BuildContext context) {
    return DateStrip(
      days: GalleryFixtures.week,
      selected: GalleryFixtures.week[2],
      today: GalleryFixtures.week[2],
      onSelect: (_) {},
    );
  }
}

class _TopBarStates extends StatelessWidget {
  const _TopBarStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MadarTopBar.root(),
        MadarTopBar.detail(title: 'نايل سات', onBack: () {}),
      ],
    );
  }
}

class _EmptyStates extends StatelessWidget {
  const _EmptyStates();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        EmptyState(title: l.emptyDayTitle, body: l.emptyDayBody),
        EmptyState(
          kind: EmptyStateKind.error,
          title: l.loadFailedTitle,
          body: l.errorInternal,
          action: TextButton(onPressed: () {}, child: Text(l.retry)),
        ),
        EmptyState(kind: EmptyStateKind.allClear, title: l.finished),
      ],
    );
  }
}

class _NavStates extends StatelessWidget {
  const _NavStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final tab in MadarTab.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s2),
            child: MadarBottomNav(current: tab, favoritesBadge: tab == MadarTab.favorites ? 2 : 0),
          ),
      ],
    );
  }
}
