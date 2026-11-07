import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/clip_controller.dart';
import '../../../core/config/remote_config.dart';
import '../../../core/format/clock.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/live_state.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/generated/models/satellite_ref.dart';
import '../../../core/network/swr_snapshot.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../../my_satellites/data/my_satellites_provider.dart';
import '../data/match_detail_providers.dart';
import '../domain/carriage_order.dart';
import '../domain/match_detail_live.dart';
import 'live_center/live_center.dart';
import 'match_follow_button.dart';
import 'match_hero.dart';
import 'match_info_cards.dart';
import 'where_to_watch_slivers.dart';
import 'where_to_watch_state.dart';

/// The back-to-top button shows once the list has scrolled this many screen heights.
const int _backToTopScreens = 2;

/// Room under the last card, so the back-to-top button never covers it.
const double _endPadding = MadarSpace.s8 * 2;

/// How many screens a push's `?section=channels` may scroll while «أين تشاهد» isn't built yet.
const int _maxRevealSteps = 40;

/// The section name that scrolls S3 to its channels.
const String _channelsSection = 'channels';

/// S3 Match detail: the hero, where to watch (my satellites, other satellites, platforms),
/// the manual broadcasters, and the stadium and Egyptian broadcaster.
///
/// It reads `GET /v1/matches/{id}` stale-while-revalidate and revalidates every 60 s while
/// it is on screen. Live state comes only from `/v1/live` (SC-008). It is always pushed, so
/// it has a back arrow; leaving it stops any clip that is playing.
class MatchDetailPage extends ConsumerStatefulWidget {
  const MatchDetailPage({super.key, required this.matchId, this.section});

  final int matchId;

  /// `channels` when a push opens S3 at its channels; anything else opens it from the top.
  final String? section;

  @override
  ConsumerState<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends ConsumerState<MatchDetailPage> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _showBackToTop = ValueNotifier(false);
  final GlobalKey _channelsKey = GlobalKey();

  /// `?section=channels` scrolls once per opening, so a re-read never moves the fan.
  bool _revealed = false;

  /// The last live state seen. A state expiring to null doesn't clear it, so a change across
  /// that gap still reads the match once.
  LiveState? _lastLive;

  /// Kept so [dispose] can stop the clip: a `ref` cannot be used there.
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MatchDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go_router keeps this state when only the path's ID or the query changes.
    if (oldWidget.matchId != widget.matchId) {
      _revealed = false;
      _lastLive = null;
    } else if (oldWidget.section != widget.section) {
      _revealed = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _stopClip();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _showBackToTop.dispose();
    super.dispose();
  }

  /// Leaving S3 stops a clip that is playing (one shared player, R26). Nothing is created
  /// when no clip was ever started.
  void _stopClip() {
    final container = _container;
    if (container == null ||
        !container.exists(clipControllerProvider) ||
        container.read(clipControllerProvider).phase == ClipPhase.idle) {
      return;
    }
    unawaited(
      container.read(clipControllerProvider.notifier).stop().catchError(
        (Object error, StackTrace stackTrace) {
          // Best effort: with the whole scope going away there is no player left to stop.
          // Crash reporting arrives on D3, behind its interface; until then, the log.
          developer.log(
            'stopping the clip on leaving failed',
            name: 'madar.audio',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _showBackToTop.value = position.pixels > position.viewportDimension * _backToTopScreens;
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      unawaited(
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
      );
    }
  }

  /// Reads the match once when what the timeline shows may have changed (FR-055, R13): the
  /// score or the status. Live values still come only from `/v1/live`, and the 60 s timer
  /// stays. Nothing here runs with the flag off, so S3 asks for no more than it did.
  void _onLiveState(LiveState? next) {
    if (next == null) return;
    final before = _lastLive;
    _lastLive = next;
    if (before == null || !ref.read(liveCenterEnabledProvider)) return;
    if (before.score != next.score || before.status != next.status) _revalidate();
  }

  /// Once the page first has a match: scrolls to «أين تشاهد», building it first if a long
  /// timeline keeps its sliver out of range.
  Future<void> _revealChannels() async {
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    for (var step = 0; step < _maxRevealSteps; step++) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _channelsKey.currentContext;
      if (target != null) {
        if (!target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOut,
        );
        return;
      }
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _scroll.jumpTo(
        (position.pixels + position.viewportDimension).clamp(0, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  /// The poll and «تحديث»: the provider owns the cycle, including asking the catalogue
  /// again when its first load failed.
  void _revalidate() => ref.read(matchDetailProvider(widget.matchId).notifier).revalidate();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final detail = ref.watch(matchDetailProvider(widget.matchId));
    final snapshot = detail.value;
    final match = snapshot?.data;
    final now = ref.watch(clockProvider)();
    // Only this match's state: the whole map is replaced every 30 s, and the page should
    // not rebuild for matches it does not show (`LiveState` has value equality).
    final live = ref.watch(liveStatesProvider.select((states) => states[widget.matchId]));
    final shown = match == null ? null : detailWithLiveState(match, live);
    _lastLive ??= live;
    ref.listen(
      liveStatesProvider.select((states) => states[widget.matchId]),
      (_, next) => _onLiveState(next),
    );
    if (shown != null && widget.section == _channelsSection && !_revealed) {
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_revealChannels()));
    }

    final Widget body;
    if (shown != null && snapshot != null) {
      body = _Loaded(
        match: shown,
        snapshot: snapshot,
        now: now,
        controller: _scroll,
        showBackToTop: _showBackToTop,
        onBackToTop: _scrollToTop,
        onRefresh: _revalidate,
        channelsKey: _channelsKey,
      );
    } else if (detail.hasError) {
      body = _FailureView(error: detail.error, onRetry: _revalidate);
    } else {
      body = const Skeleton();
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.detail(
              title: l.s3Title,
              onBack: _back,
              actions: shown == null
                  ? const []
                  : [
                      MatchFollowButton(
                        matchId: widget.matchId,
                        kickoffAt: shown.kickoffAt,
                        status: shown.status,
                        estimated: shown.estimated,
                      ),
                    ],
            ),
            Expanded(
              child: LivePollingScope(
                hasLiveOrImminent:
                    match != null && hasLiveOrImminent([summaryOfDetail(match)], now: now),
                onRevalidate: _revalidate,
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen once there is a match to show.
class _Loaded extends ConsumerWidget {
  const _Loaded({
    required this.match,
    required this.snapshot,
    required this.now,
    required this.controller,
    required this.showBackToTop,
    required this.onBackToTop,
    required this.onRefresh,
    required this.channelsKey,
  });

  final MatchDetail match;
  final SwrSnapshot<MatchDetail> snapshot;
  final DateTime now;
  final ScrollController controller;
  final ValueListenable<bool> showBackToTop;
  final VoidCallback onBackToTop;
  final VoidCallback onRefresh;
  final GlobalKey channelsKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(whereToWatchProvider(match.id));
    final receptionUrls = ref.watch(receptionUrlsProvider);
    // Two bundled defaults are not "yours": until D3 stores a choice, the part is titled
    // by their names (constitution I, US3 scenario 4).
    final mineNames = ref.watch(mySatelliteNamesProvider);
    final mineTitle = ref.watch(chosenSatelliteIdsProvider) != null
        ? l.onMySatellites
        : mineNames.isEmpty
            ? l.s3OnDefaultSatellites
            // «على نايل سات وبدر»: the names joined as the design writes them.
            : l.s3OnSatellites(mineNames.join(' و'));

    // My satellites by id: the person's own set once chosen, otherwise O10's defaults
    // resolved through the catalogue (D3, constitution I).
    final mine = ref.watch(mySatelliteIdsProvider);
    final all = orderCarriages(
      carriages: match.carriages,
      platforms: match.platforms,
      isMine: (satellite) => satellite != null && mine.contains(satellite.id),
    );
    final shown = filterWhereToWatch(all, freeOnly: state.freeOnly, query: state.query);
    final manual = manualBroadcasts(match);
    final age = snapshot.staleAge(Freshness.matchDetail, now: now);

    final whereToWatch = WhereToWatchSlivers(
      l: l,
      matchId: match.id,
      kickoffAt: match.kickoffAt,
      status: match.status,
      estimated: match.estimated,
      showChooseSatellites: ref.watch(usesDefaultSatellitesProvider),
      onChooseSatellites: () => context.push('/settings/satellites'),
      all: all,
      shown: shown,
      state: state,
      controller: ref.read(whereToWatchProvider(match.id).notifier),
      mineTitle: mineTitle,
      receptionOf: (SatelliteRef? satellite) =>
          satellite == null ? null : receptionUrls[satellite.id],
      onWatchReception: (url) => _open(context, ref, url),
      onRefresh: onRefresh,
      toolbarKey: channelsKey,
    );

    return Stack(
      children: [
        CustomScrollView(
          controller: controller,
          slivers: [
            if (age != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: MadarSpace.s4,
                    vertical: MadarSpace.s2,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StaleHint(age: age),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: MatchHero(
                match: match,
                now: now,
                highlightScore: ref.watch(liveCenterEnabledProvider),
                onOpenTeam: (teamId) => context.push('/team/$teamId'),
                onOpenCompetition: (competitionId) =>
                    context.push('/competition/$competitionId'),
              ),
            ),
            LiveCenterSliver(match: match, age: age),
            if (manual.isNotEmpty) SliverToBoxAdapter(child: ManualBroadcasterCards(entries: manual)),
            ...whereToWatch.build(),
            if (MatchInfoSection.hasContent(match))
              SliverToBoxAdapter(child: MatchInfoSection(match: match)),
            const SliverToBoxAdapter(child: SizedBox(height: _endPadding)),
          ],
        ),
        PositionedDirectional(
          start: MadarSpace.s4,
          bottom: MadarSpace.s4,
          child: ValueListenableBuilder<bool>(
            valueListenable: showBackToTop,
            builder: (context, show, _) =>
                show ? _BackToTopButton(onTap: onBackToTop) : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Opens the reception video outside the app, and says so when nothing could open it.
  Future<void> _open(BuildContext context, WidgetRef ref, Uri url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).s3OpenFailed;
    final opened = await ref.read(urlOpenerProvider).open(url);
    if (!opened) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }
}

class _BackToTopButton extends StatelessWidget {
  const _BackToTopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Material(
      color: colors.textPrimary,
      elevation: MadarSpace.s1,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward,
                  size: MadarText.textBody.fontSize,
                  color: colors.textOnInverse,
                ),
                const SizedBox(width: MadarSpace.s2),
                Text(
                  l.s3BackToTop,
                  style: MadarText.textLabel.copyWith(color: colors.textOnInverse),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No copy and the request failed: no connection, or an API error shown as its Arabic copy
/// (never `error.message`), with a retry.
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
