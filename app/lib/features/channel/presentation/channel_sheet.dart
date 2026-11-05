import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/media_image.dart';
import '../../../core/format/clock.dart';
import '../../../core/format/digits.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/channel_detail.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_snapshot.dart';
import '../../../core/platform/share_service.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../follows/domain/follow_set.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../../my_satellites/data/my_satellites_provider.dart';
import '../data/channel_providers.dart';
import '../domain/channel_sections.dart';
import 'channel_sections.dart';

/// How much of the screen the sheet covers, as the board draws it.
const double _sheetHeight = 0.92;

/// S6 Channel, as a modal sheet over the screen it was opened from (§S6, FR-042).
///
/// It reads `GET /v1/channels/{id}` stale-while-revalidate, shows the channel's own carriage
/// first (the frequency with no further tap, SC-008), then its other carriages, its upcoming
/// matches and its frequency history. The route is a page, so `/channel/:id` stays
/// deep-linkable and a push notification can open it; the sheet is that page's body.
///
/// Live values on the match rows come only from `/v1/live` (`LivePollingScope`).
class ChannelSheetPage extends ConsumerStatefulWidget {
  const ChannelSheetPage({super.key, required this.channelId});

  final int channelId;

  @override
  ConsumerState<ChannelSheetPage> createState() => _ChannelSheetPageState();
}

class _ChannelSheetPageState extends ConsumerState<ChannelSheetPage> {
  /// Closes the sheet: the screen below comes back, or S2 when it was a deep link.
  void _close() => context.canPop() ? context.pop() : context.go('/');

  void _revalidate() => ref.read(channelDetailProvider(widget.channelId).notifier).revalidate();

  Future<void> _refresh() =>
      ref.read(channelDetailProvider(widget.channelId).notifier).refresh();

  void _openMatch(int matchId) => context.push('/match/$matchId');

  Future<void> _share(String name) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final shared = await ref.read(shareServiceProvider).share(text: l.s6ShareText(name));
    if (!shared) messenger?.showSnackBar(SnackBar(content: Text(l.s3OpenFailed)));
  }

  Future<void> _copy(String tuning) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: tuning));
    messenger?.showSnackBar(SnackBar(content: Text(l.copiedFrequency)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final answer = ref.watch(channelDetailProvider(widget.channelId));
    final snapshot = answer.value;
    final detail = snapshot?.data;
    final now = ref.watch(clockProvider)();
    final live = ref.watch(liveStatesProvider);
    final mine = ref.watch(mySatelliteIdsProvider);
    final following = ref.watch(followSetValueProvider).channels.contains(widget.channelId);

    final rows = detail == null
        ? const <MatchSummary>[]
        : applyLiveStates(detail.upcomingMatches, live);

    final Widget body;
    if (detail != null && snapshot != null) {
      body = _Loaded(
        detail: detail,
        snapshot: snapshot,
        now: now,
        rows: rows,
        mine: mine,
        following: following,
        onCopy: _copy,
        onShare: () => _share(detail.displayName ?? detail.name),
        onFollow: () =>
            ref.read(followsRepositoryProvider).toggle(FollowKind.channel, widget.channelId),
        onOpenMatch: _openMatch,
        onRefresh: _refresh,
      );
    } else if (answer.hasError) {
      body = _FailureView(error: answer.error, onRetry: _revalidate);
    } else {
      body = const Skeleton();
    }

    final height = MediaQuery.sizeOf(context).height * _sheetHeight;

    return Scaffold(
      // The scrim is the scaffold's own ground: the route below stays painted (`opaque: false`
      // in the router), dimmed by the app's overlay colour. A Scaffold keeps `SnackBar`s (the
      // copy confirmation, a refused share) inside this screen.
      backgroundColor: colors.overlay,
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: l.back,
              button: true,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface1,
                  borderRadius: const BorderRadiusDirectional.vertical(
                    top: Radius.circular(MadarRadii.xxl),
                  ),
                  border: Border(
                    top: BorderSide(color: colors.divider, width: MadarLine.hairline),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const _Handle(),
                      Expanded(
                        child: LivePollingScope(
                          hasLiveOrImminent:
                              detail != null && hasLiveOrImminent(detail.upcomingMatches, now: now),
                          onRevalidate: _revalidate,
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grab handle at the top of the sheet.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: MadarSpace.s2, bottom: MadarSpace.s2),
      child: Container(
        width: MadarSpace.s12 - MadarSpace.s4,
        height: MadarSpace.s1,
        decoration: BoxDecoration(
          color: colors.dividerStrong,
          borderRadius: BorderRadius.circular(MadarRadii.pill),
        ),
      ),
    );
  }
}

/// The sheet once there is a channel to show.
class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.detail,
    required this.snapshot,
    required this.now,
    required this.rows,
    required this.mine,
    required this.following,
    required this.onCopy,
    required this.onShare,
    required this.onFollow,
    required this.onOpenMatch,
    required this.onRefresh,
  });

  final ChannelDetail detail;
  final SwrSnapshot<ChannelDetail> snapshot;
  final DateTime now;
  final List<MatchSummary> rows;
  final Set<int> mine;
  final bool following;
  final void Function(String tuning) onCopy;
  final VoidCallback onShare;
  final VoidCallback onFollow;
  final void Function(int matchId) onOpenMatch;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final name = detail.displayName ?? detail.name;
    final carriage = ChannelCarriageView.of(detail);
    final frequency = detail.frequency;
    final others = otherCarriages(detail, mySatelliteIds: mine);
    final history = frequencyHistory(detail.recentFrequencyChanges);
    final age = snapshot.staleAge(Freshness.channels, now: now);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s4,
          0,
          MadarSpace.s4,
          MadarSpace.s6,
        ),
        children: [
          ChannelSheetHeader(
            detail: ChannelSheetHeaderData(
              logo: mediaImage(context, detail.logo),
              category: detail.category,
              country: detail.country,
            ),
            name: name,
            onShare: onShare,
          ),
          if (age != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: MadarSpace.s2),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StaleHint(age: age),
              ),
            ),
          const SizedBox(height: MadarSpace.s3),
          CarriageCard(
            carriage: carriage,
            isMine: detail.satellite != null && mine.contains(detail.satellite!.id),
            onCopy: () => onCopy(
              frequency == null
                  ? ''
                  : [
                      MadarDigits.plain(frequency.mhz),
                      frequency.pol.json ?? '',
                      MadarDigits.plain(frequency.sr),
                    ].join(' '),
            ),
          ),
          const SizedBox(height: MadarSpace.s3),
          FollowChannelButton(following: following, onPressed: onFollow),
          if (others.isNotEmpty) OtherCarriagesSection(carriages: others),
          ChannelUpcomingSection(
            matches: rows,
            now: now,
            onOpen: (match) => onOpenMatch(match.id),
          ),
          if (history.isNotEmpty) FrequencyHistorySection(changes: history),
          const SizedBox(height: MadarSpace.s2),
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
