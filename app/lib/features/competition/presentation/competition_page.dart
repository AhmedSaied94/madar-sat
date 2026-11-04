import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/media_image.dart';
import '../../../core/format/clock.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/competition_detail.dart';
import '../../../core/network/generated/models/live_state.dart';
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
import '../../matches/domain/match_days.dart';
import '../../matches/presentation/match_days_list.dart';
import '../data/competition_providers.dart';
import 'competition_sections.dart';

/// S8 Competition (§S8, FR-042): the header, the follow toggle, the matches by local day and
/// the «حقوق البث» section.
///
/// It reads `GET /v1/competitions/{id}` stale-while-revalidate and revalidates every 60 s
/// while it is on screen; pull to refresh waits for the server. Live values on the rows come
/// only from `/v1/live` (SC-008). Hide/show and the rights-holder pages arrive later (D8,
/// D7), so neither is drawn here.
class CompetitionPage extends ConsumerStatefulWidget {
  const CompetitionPage({super.key, required this.competitionId});

  final int competitionId;

  @override
  ConsumerState<CompetitionPage> createState() => _CompetitionPageState();
}

class _CompetitionPageState extends ConsumerState<CompetitionPage> {
  MatchTab _tab = MatchTab.upcoming;

  /// The page's own scroll, so the header's «حقوق البث» shortcut can reach the section at the
  /// end of the list.
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revalidate() =>
      ref.read(competitionDetailProvider(widget.competitionId).notifier).revalidate();

  Future<void> _refresh() =>
      ref.read(competitionDetailProvider(widget.competitionId).notifier).refresh();

  void _openMatch(int matchId) => context.push('/match/$matchId');

  /// The rights section is the last thing on the page, so the shortcut is the end of the
  /// scroll: asking for it by position works even though the sliver is not built yet.
  Future<void> _scrollToRights() async {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _scroll.jumpTo(target);
      return;
    }
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final answer = ref.watch(competitionDetailProvider(widget.competitionId));
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
        controller: _scroll,
        following: follows.competitions.contains(widget.competitionId),
        followedTeams: follows.teams,
        onTab: (tab) => setState(() => _tab = tab),
        onFollow: () => ref
            .read(followsRepositoryProvider)
            .toggle(FollowKind.competition, widget.competitionId),
        onOpenRights: _scrollToRights,
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
              title: detail?.name ?? l.s8Title,
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The page once there is a competition to show.
class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.detail,
    required this.snapshot,
    required this.now,
    required this.live,
    required this.tab,
    required this.controller,
    required this.following,
    required this.followedTeams,
    required this.onTab,
    required this.onFollow,
    required this.onOpenRights,
    required this.onOpenMatch,
    required this.onRefresh,
    required this.onRevalidate,
  });

  final CompetitionDetail detail;
  final SwrSnapshot<CompetitionDetail> snapshot;
  final DateTime now;
  final Map<int, LiveState> live;
  final MatchTab tab;
  final ScrollController controller;
  final bool following;
  final Set<int> followedTeams;
  final ValueChanged<MatchTab> onTab;
  final VoidCallback onFollow;
  final VoidCallback onOpenRights;
  final ValueChanged<int> onOpenMatch;
  final Future<void> Function() onRefresh;
  final VoidCallback onRevalidate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final zone = MadarDisplayScope.zoneOf(context);
    final rows = tab == MatchTab.upcoming ? detail.upcoming : detail.recent;
    final shown = applyLiveStates(rows, live);
    final days = matchDays(shown, tab: tab, offsetAt: zone.offsetAtUtc);
    final age = snapshot.staleAge(Freshness.matchDetail, now: now);
    final hasRights = detail.rightsHolders.isNotEmpty;

    return LivePollingScope(
      hasLiveOrImminent: hasLiveOrImminent(detail.upcoming, now: now),
      onRevalidate: onRevalidate,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CompetitionHeader(
                detail: detail,
                logo: mediaImage(context, detail.logo),
                following: following,
                onFollow: onFollow,
                showRightsShortcut: hasRights,
                onOpenRights: onOpenRights,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
                child: Segmented<MatchTab>(
                  options: [
                    SegmentedOption(value: MatchTab.upcoming, label: l.matchTabUpcoming),
                    SegmentedOption(value: MatchTab.results, label: l.matchTabResults),
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
            if (!hasMatchDays(days))
              SliverToBoxAdapter(child: _Empty(tab: tab))
            else
              SliverToBoxAdapter(
                child: MatchDaysList(
                  days: days,
                  now: now,
                  followedTeams: followedTeams,
                  onOpen: (match) => onOpenMatch(match.id),
                ),
              ),
            if (hasRights)
              SliverToBoxAdapter(
                child: RightsHoldersSection(holders: detail.rightsHolders),
              ),
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

  final MatchTab tab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: MadarSpace.s6),
      child: EmptyState(title: tab == MatchTab.upcoming ? l.s8NoUpcoming : l.s7NoResults),
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
