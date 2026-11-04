import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/media_image.dart';
import '../../../core/format/clock.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/live_state.dart';
import '../../../core/network/generated/models/team_detail.dart';
import '../../../core/network/swr_snapshot.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/display_scope.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../follows/domain/follow_set.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../data/team_providers.dart';
import '../domain/team_matches.dart';
import 'team_header.dart';
import 'team_matches_list.dart';

/// S7 Team (§S7, FR-042): the header, the follow toggle, and the two tabs of matches grouped
/// by the local day of their kickoff.
///
/// It reads `GET /v1/teams/{id}` stale-while-revalidate and revalidates every 60 s while it is
/// on screen; pull to refresh waits for the server. Live values on the rows come only from
/// `/v1/live` (SC-008).
class TeamPage extends ConsumerStatefulWidget {
  const TeamPage({super.key, required this.teamId});

  final int teamId;

  @override
  ConsumerState<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends ConsumerState<TeamPage> {
  TeamTab _tab = TeamTab.upcoming;

  void _revalidate() => ref.read(teamDetailProvider(widget.teamId).notifier).revalidate();

  Future<void> _refresh() => ref.read(teamDetailProvider(widget.teamId).notifier).refresh();

  void _openMatch(int matchId) => context.push('/match/$matchId');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final answer = ref.watch(teamDetailProvider(widget.teamId));
    final snapshot = answer.value;
    final detail = snapshot?.data;
    final now = ref.watch(clockProvider)();
    final live = ref.watch(liveStatesProvider);
    final follows = ref.watch(followSetValueProvider);

    final Widget body;
    if (detail != null && snapshot != null) {
      body = _Loaded(
        detail: detail,
        snapshot: snapshot,
        now: now,
        live: live,
        tab: _tab,
        following: follows.teams.contains(widget.teamId),
        followedTeams: follows.teams,
        onTab: (tab) => setState(() => _tab = tab),
        onFollow: () => ref.read(followsRepositoryProvider).toggle(FollowKind.team, widget.teamId),
        onOpenMatch: _openMatch,
        onRefresh: _refresh,
        onRevalidate: _revalidate,
      );
    } else if (answer.hasError) {
      body = _FailureView(error: answer.error, onRetry: _revalidate);
    } else {
      body = const Skeleton();
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.detail(
              title: detail?.name ?? l.s7Title,
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The page once there is a team to show.
class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.detail,
    required this.snapshot,
    required this.now,
    required this.live,
    required this.tab,
    required this.following,
    required this.followedTeams,
    required this.onTab,
    required this.onFollow,
    required this.onOpenMatch,
    required this.onRefresh,
    required this.onRevalidate,
  });

  final TeamDetail detail;
  final SwrSnapshot<TeamDetail> snapshot;
  final DateTime now;
  final Map<int, LiveState> live;
  final TeamTab tab;
  final bool following;
  final Set<int> followedTeams;
  final ValueChanged<TeamTab> onTab;
  final VoidCallback onFollow;
  final ValueChanged<int> onOpenMatch;
  final Future<void> Function() onRefresh;
  final VoidCallback onRevalidate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final zone = MadarDisplayScope.zoneOf(context);
    final rows = tab == TeamTab.upcoming ? detail.upcoming : detail.recent;
    final shown = applyLiveStates(rows, live);
    final days = teamMatchDays(shown, tab: tab, offsetAt: zone.offsetAtUtc);
    final age = snapshot.staleAge(Freshness.matchDetail, now: now);

    return LivePollingScope(
      hasLiveOrImminent: hasLiveOrImminent(detail.upcoming, now: now),
      onRevalidate: onRevalidate,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: TeamHeader(
                detail: detail,
                logo: mediaImage(context, detail.logo),
                following: following,
                onFollow: onFollow,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
                child: Segmented<TeamTab>(
                  options: [
                    SegmentedOption(value: TeamTab.upcoming, label: l.s7Upcoming),
                    SegmentedOption(value: TeamTab.results, label: l.s7Results),
                  ],
                  selected: tab,
                  onChanged: onTab,
                ),
              ),
            ),
            if (age != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    MadarSpace.s4,
                    MadarSpace.s2,
                    MadarSpace.s4,
                    0,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StaleHint(age: age),
                  ),
                ),
              ),
            if (!hasTeamMatches(days))
              SliverToBoxAdapter(child: _Empty(tab: tab))
            else
              SliverToBoxAdapter(
                child: TeamMatchesList(
                  days: days,
                  tab: tab,
                  now: now,
                  followedTeams: followedTeams,
                  onOpen: (match) => onOpenMatch(match.id),
                ),
              ),
            if (tab == TeamTab.upcoming) const SliverToBoxAdapter(child: _ListNote()),
            const SliverToBoxAdapter(child: SizedBox(height: MadarSpace.s6)),
          ],
        ),
      ),
    );
  }
}

/// «لا توجد مباريات قادمة» / «لا توجد نتائج».
class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final TeamTab tab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s6),
      child: EmptyState(title: tab == TeamTab.upcoming ? l.s7NoUpcoming : l.s7NoResults),
    );
  }
}

/// «تظهر المباريات التالية فور إعلان الجدول»: the board's note under the upcoming list.
class _ListNote extends StatelessWidget {
  const _ListNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s5,
        MadarSpace.s4,
        MadarSpace.s5,
        0,
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: MadarText.textCaption.fontSize,
            color: colors.textTertiary,
          ),
          const SizedBox(width: MadarSpace.s1),
          Flexible(
            child: Text(
              l.s7ListNote,
              style: MadarText.textCaption.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// No copy and the request failed: no connection, or an API error shown as its Arabic copy,
/// with a retry.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failure = error is ApiFailure ? error! as ApiFailure : null;
    final offline = failure?.isOffline ?? false;
    return EmptyState(
      kind: EmptyStateKind.error,
      title: offline ? l.noConnectionTitle : l.loadFailedTitle,
      body: offline ? l.noConnectionBody : l.errorCopy(failure?.code),
      action: TextButton(onPressed: onRetry, child: Text(l.retry)),
    );
  }
}
