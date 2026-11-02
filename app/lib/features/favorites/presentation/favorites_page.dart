import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/bidi.dart';
import '../../../core/format/digits.dart';
import '../../../core/format/time.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/generated/models/team_detail.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/button.dart';
import '../../../design/components/display_scope.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/frequency_readout.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../follows/domain/follow_set.dart';
import '../../system/presentation/system_views.dart';
import '../data/favorites_providers.dart';

/// S9 Favorites: the next three matches of what is followed, then the followed teams.
///
/// D2's follow actions do not exist yet (D5's S8 brings competitions, channels and
/// commentators), so those sections are absent rather than empty (contract app-screens).
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final follows = ref.watch(followSetValueProvider);
    final upcoming = ref.watch(favoriteUpcomingProvider);
    final teams = ref.watch(favoriteTeamsProvider);
    final repository = ref.read(followsRepositoryProvider);

    return ExitGuard(
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: MadarSpace.s12 + MadarSpace.s2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: MadarSpace.s4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.navFavorites,
                          style: MadarText.heading1.copyWith(
                            color: colors.textPrimary,
                            fontSize: MadarText.heading1.fontSize!,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.add,
                        onPressed: () => context.push('/onboarding/teams'),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: follows.isEmpty
                    ? EmptyState(
                        title: l.s9EmptyTitle,
                        body: l.s9EmptyBody,
                        action: MadarButton(
                          label: l.addTeams,
                          icon: Icons.add,
                          variant: MadarButtonVariant.secondary,
                          onPressed: () => context.push('/onboarding/teams'),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s6),
                        children: [
                          _SectionHeader(title: l.s9Upcoming, action: l.s9ShowAll, onAction: () => context.go('/')),
                          switch (upcoming) {
                            final async when async.isLoading => const SizedBox(
                                height: 160,
                                child: Skeleton(),
                              ),
                            final async when async.hasError => SystemFailureView(
                                failure: const ApiFailure(),
                                onRetry: () => ref.invalidate(favoriteUpcomingProvider),
                              ),
                            final async => ((async.value ?? const <MatchSummary>[]).isEmpty)
                                ? Padding(
                                    padding: const EdgeInsetsDirectional.symmetric(
                                      horizontal: MadarSpace.s5,
                                      vertical: MadarSpace.s4,
                                    ),
                                    child: Text(
                                      l.s9NoUpcoming,
                                      style: MadarText.textBody.copyWith(
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 168,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsetsDirectional.symmetric(
                                        horizontal: MadarSpace.s4,
                                      ),
                                      itemCount: (async.value ?? const []).length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(width: MadarSpace.s2),
                                      itemBuilder: (context, index) => _UpcomingCard(
                                        match: async.value![index],
                                        onTap: () => context.push('/match/${async.value![index].id}'),
                                      ),
                                    ),
                                  ),
                          },
                          _SectionHeader(
                            title: l.s9TeamsSection,
                            count: follows.teams.length,
                            action: l.add,
                            onAction: () => context.push('/onboarding/teams'),
                          ),
                          switch (teams) {
                            final async when async.isLoading => const Skeleton(),
                            final async when async.hasError => SystemFailureView(
                                failure: const ApiFailure(),
                                onRetry: () => ref.invalidate(favoriteTeamsProvider),
                              ),
                            final async => MadarListGroup(
                                children: [
                                  for (final team
                                      in async.value ?? const <TeamDetail>[])
                                    MadarListRow(
                                      key: ValueKey(team.id),
                                      title: team.name,
                                      subtitle: team.primaryCompetition?.name,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.notifications_none,
                                            color: colors.textSecondary,
                                            size: MadarText.heading2.fontSize,
                                          ),
                                          IconButton(
                                            tooltip: l.s9RemoveTeam(team.name),
                                            onPressed: () => repository
                                                .set(FollowKind.team, team.id, follow: false),
                                            icon: Icon(
                                              Icons.close,
                                              size: (MadarText.textStrong.fontSize ?? 0) + 2,
                                              color: colors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => context.push('/team/${team.id}'),
                                    ),
                                ],
                              ),
                          },
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MadarBottomNav(
          current: MadarTab.favorites,
          onSelect: (tab) => switch (tab) {
            MadarTab.matches => context.go('/'),
            MadarTab.mySatellites => context.go('/my-satellites'),
            MadarTab.frequencies => context.go('/satellites'),
            MadarTab.favorites => context.go('/favorites'),
            MadarTab.more => context.go('/more'),
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.onAction,
    this.count = 0,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s5,
        MadarSpace.s5,
        MadarSpace.s3,
        MadarSpace.s2,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: MadarText.textLabel.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: MadarSpace.s2),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s1),
              decoration: BoxDecoration(
                color: colors.surface3,
                borderRadius: BorderRadius.circular(MadarRadii.pill),
              ),
              child: Text(
                MadarDigits.plain(count),
                style: MadarText.textMicro.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
              child: Text(action!, style: MadarText.textCaption),
            ),
        ],
      ),
    );
  }
}

/// One of the three upcoming cards: when, who, where, and the tuning numbers.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.match, required this.onTap});

  final MatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final zone = MadarDisplayScope.zoneOf(context);
    final use24h = MadarDisplayScope.use24hOf(context);
    final kickoff = match.kickoffAt;
    final time = MadarTime.kickoff(kickoff, am: l.amMarker, pm: l.pmMarker, use24h: use24h, zone: zone.fixed);
    final wall = kickoff == null ? null : zone.wallClock(kickoff);
    final today = zone.wallClock(DateTime.now());
    final when = time == null
        ? l.timeTbd
        : wall == null
            ? time
            : (wall.year == today.year && wall.month == today.month && wall.day == today.day)
                ? l.todayAt(time)
                : l.dayAt(MadarDates.weekdayShort(l, wall), time);
    final headline = match.broadcast.headline;
    final first = headline.isEmpty ? null : headline.first;

    return Semantics(
      button: true,
      label: '${match.home.name} ${l.vs(match.away.name, match.home.name)}',
      excludeSemantics: true,
      child: SizedBox(
        width: MadarSpace.s12 * 5,
        child: Material(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(MadarRadii.xl),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MadarRadii.xl),
            child: Container(
              padding: const EdgeInsetsDirectional.all(MadarSpace.s3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MadarRadii.xl),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        when,
                        style: MadarText.textCaption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.notifications_active,
                        size: MadarText.textLabel.fontSize,
                        color: colors.accentText,
                      ),
                    ],
                  ),
                  const SizedBox(height: MadarSpace.s2),
                  Row(
                    children: [
                      TeamCrest(name: match.home.name, size: MadarSpace.s8),
                      const SizedBox(width: MadarSpace.s1),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${match.home.name} × ${match.away.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MadarText.textLabel.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              match.competition.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (first != null)
                    Row(
                      children: [
                        Flexible(
                          child: LtrIsland(
                            first.name,
                            style: MadarText.textCaption.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (first.frequency != null)
                          FrequencyReadout(
                            mhz: first.frequency!.mhz,
                            polarization: first.frequency!.pol,
                            size: FrequencyReadoutSize.standard,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
