import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_snapshot.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../l10n/app_localizations.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../data/my_satellites_provider.dart';
import '../data/satellite_matches_provider.dart';
import '../data/satellite_selection.dart';
import '../domain/competition_groups.dart';
import 'competition_header.dart';
import 'satellite_chips.dart';
import 'satellite_match_row.dart';

/// S4 «أقماري»: the day's matches that are carried on my satellites.
///
/// The list is asked of the server for exactly the chosen satellites (never filtered from
/// S2's rows), grouped by competition, with each match's carriages and readouts.
class MySatellitesPage extends ConsumerWidget {
  const MySatellitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellites = ref.watch(satellitesProvider);
    final chips = ref.watch(mySatelliteChipsProvider);
    final selectedIds = ref.watch(selectedSatelliteIdsProvider);
    final selection = ref.read(satelliteSelectionProvider.notifier);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TitleBar(title: l.navSatellites, onSearch: () => context.push('/search')),
            if (chips.isNotEmpty)
              SatelliteChips(
                satellites: chips,
                selectedIds: selectedIds,
                onToggle: selection.toggle,
                onSelectAll: selection.selectAll,
              ),
            Expanded(
              child: switch (satellites.value) {
                null when satellites.hasError => _Failure(
                    error: satellites.error,
                    onRetry: () => ref.invalidate(satellitesProvider),
                  ),
                null => const Skeleton(),
                _ when selectedIds.isEmpty => _NoSatellitesChosen(
                    onChoose: chips.isEmpty
                        ? () => context.go('/satellites')
                        : selection.selectAll,
                  ),
                _ => _DayOfMatches(
                    satelliteIds: selectedIds,
                    satelliteNames: [
                      for (final satellite in chips)
                        if (selectedIds.contains(satellite.id)) satellite.nameAr,
                    ],
                  ),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: MadarBottomNav(
        current: MadarTab.mySatellites,
        onSelect: (tab) => switch (tab) {
          MadarTab.matches => context.go('/'),
          MadarTab.mySatellites => context.go('/my-satellites'),
          MadarTab.frequencies => context.go('/satellites'),
          MadarTab.favorites => context.go('/favorites'),
          MadarTab.more => context.go('/settings'),
        },
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.onSearch});

  final String title;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: MadarSpace.s4, end: MadarSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MadarText.heading1.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
          IconButton(
            onPressed: onSearch,
            tooltip: l.search,
            icon: Icon(Icons.search, color: colors.textPrimary),
            constraints: const BoxConstraints(
              minWidth: MadarLayout.touchMin,
              minHeight: MadarLayout.touchMin,
            ),
          ),
        ],
      ),
    );
  }
}

/// The matches of the local day on [satelliteIds], from the cache and then the server.
class _DayOfMatches extends ConsumerWidget {
  const _DayOfMatches({required this.satelliteIds, required this.satelliteNames});

  final Set<int> satelliteIds;
  final List<String> satelliteNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final clock = ref.watch(clockProvider);
    final localNow = clock();
    final now = localNow.toUtc();
    final query = SatelliteMatchesQuery(day: localNow, satelliteIds: satelliteIds);
    final answer = ref.watch(satelliteMatchesProvider(query));
    final liveStates = ref.watch(liveStatesProvider);

    final snapshot = answer.value;
    if (snapshot == null) {
      return answer.hasError
          ? _Failure(
              error: answer.error,
              onRetry: () => ref.invalidate(satelliteMatchesProvider(query)),
            )
          : const Skeleton();
    }

    // A cached in-play row is never shown as live on its own (FR-046).
    final rows = applyLiveStates(snapshot.data ?? const <MatchSummary>[], liveStates);
    final age = snapshot.staleAge(Freshness.matches, now: now);
    final items = _items(rows);

    return LivePollingScope(
      // The cached rows, before the merge: a copy that says "in play" is the signal.
      hasLiveOrImminent: hasLiveOrImminent(snapshot.data ?? const <MatchSummary>[], now: now),
      onRevalidate: () => ref.read(satelliteMatchesProvider(query).notifier).revalidate(),
      child: RefreshIndicator(
        onRefresh: () => ref.read(satelliteMatchesProvider(query).notifier).refresh(),
        child: CustomScrollView(
          // The list can be shorter than the screen and must still pull to refresh.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (age != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: MadarSpace.s4,
                    vertical: MadarSpace.s1,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StaleHint(age: age),
                  ),
                ),
              ),
            if (rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: l.s4NoMatchesTitle(satelliteNames.join(l.listSeparator)),
                  body: l.s4NoMatchesBody,
                ),
              )
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => switch (items[index]) {
                  _HeaderItem(:final group) => CompetitionHeader(group: group),
                  _RowItem(:final match, :final isLast) => _MatchItem(
                      match: match,
                      isLast: isLast,
                      now: now,
                    ),
                },
              ),
            const SliverPadding(padding: EdgeInsetsDirectional.only(bottom: MadarSpace.s4)),
          ],
        ),
      ),
    );
  }
}

sealed class _Item {
  const _Item();
}

class _HeaderItem extends _Item {
  const _HeaderItem(this.group);

  final CompetitionGroup group;
}

class _RowItem extends _Item {
  const _RowItem(this.match, {required this.isLast});

  final MatchSummary match;
  final bool isLast;
}

/// The groups flattened to headers and rows, so one lazy list builds only what is on screen.
List<_Item> _items(List<MatchSummary> rows) => [
      for (final group in groupByCompetition(rows)) ...[
        _HeaderItem(group),
        for (var i = 0; i < group.matches.length; i++)
          _RowItem(group.matches[i], isLast: i == group.matches.length - 1),
      ],
    ];

class _MatchItem extends StatelessWidget {
  const _MatchItem({required this.match, required this.isLast, required this.now});

  final MatchSummary match;
  final bool isLast;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Column(
      children: [
        SatelliteMatchRow(
          match: match,
          now: now,
          // push, not go: the detail needs a stack to pop back to.
          onTap: () => context.push('/match/${match.id}'),
        ),
        if (!isLast)
          Divider(
            height: MadarLine.hairline,
            thickness: MadarLine.hairline,
            color: colors.divider,
          ),
      ],
    );
  }
}

class _NoSatellitesChosen extends StatelessWidget {
  const _NoSatellitesChosen({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      title: l.s4NoSatellitesTitle,
      body: l.s4NoSatellitesBody,
      action: TextButton(onPressed: onChoose, child: Text(l.s4ChooseSatellites)),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      kind: EmptyStateKind.error,
      title: l.loadFailedTitle,
      body: l.errorCopy(error is ApiFailure ? (error! as ApiFailure).code : null),
      action: TextButton(onPressed: onRetry, child: Text(l.retry)),
    );
  }
}
