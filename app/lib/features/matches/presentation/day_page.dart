import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/components/skeleton.dart';
import '../../../design/components/stale_hint.dart';
import '../../../l10n/app_localizations.dart';
import '../data/matches_providers.dart';
import '../domain/matches_day.dart';
import 'match_group_section.dart';
import 'matches_selection.dart';

/// One day of S2: the page the day `PageView` shows for a local [day].
///
/// It reads its own day, so a swipe builds only the neighbour it reveals. Every state
/// except the skeleton is a scrollable, so pulling down revalidates in all of them.
class DayPage extends ConsumerWidget {
  const DayPage({super.key, required this.day, required this.filter});

  final DateTime day;
  final MatchesFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.madarColors;
    return switch (ref.watch(matchesDayStateProvider(day))) {
      DayLoading() => const Skeleton(),
      DayFailed(:final failure, :final isRetrying) => _Pullable(
          onRefresh: () => _refresh(ref),
          color: colors.textPrimary,
          background: colors.surface2,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _FailedState(
                failure: failure,
                onRetry: isRetrying ? null : () => ref.invalidate(matchesDayProvider(day)),
              ),
            ),
          ],
        ),
      DayLoaded(:final view) => _Pullable(
          onRefresh: () => _refresh(ref),
          color: colors.textPrimary,
          background: colors.surface2,
          slivers: _loadedSlivers(context, ref, view),
        ),
    };
  }

  List<Widget> _loadedSlivers(BuildContext context, WidgetRef ref, DayView view) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(clockProvider)();
    final groups = view.groups(filter);
    final age = view.staleAge(now);
    return [
      if (age != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: MadarSpace.s4,
              end: MadarSpace.s4,
              top: MadarSpace.s1,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StaleHint(age: age),
            ),
          ),
        ),
      if (groups.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: filter == MatchesFilter.live
              ? EmptyState(
                  title: l.emptyLiveTitle,
                  action: _TextAction(
                    label: l.s2ShowAllMatches,
                    onPressed: () =>
                        ref.read(matchesSelectionProvider.notifier).selectFilter(MatchesFilter.all),
                  ),
                )
              : EmptyState(title: l.emptyDayTitle, body: l.emptyDayBody),
        )
      else
        SliverPadding(
          padding: const EdgeInsetsDirectional.only(
            start: MadarSpace.s4,
            end: MadarSpace.s4,
            bottom: MadarSpace.s6,
          ),
          sliver: SliverList.builder(
            itemCount: groups.competitions.length + (groups.tbd.isEmpty ? 0 : 1),
            itemBuilder: (context, index) {
              void open(MatchSummary match) => context.push('/match/${match.id}');
              if (index < groups.competitions.length) {
                return CompetitionSection(
                  group: groups.competitions[index],
                  now: now,
                  onOpen: open,
                );
              }
              return TbdSection(matches: groups.tbd, now: now, onOpen: open);
            },
          ),
        ),
    ];
  }

  /// Pull to refresh: run the whole cache, revalidate, write cycle and wait for the answer,
  /// then re-read drift so the screen shows what was written (R25). A failure with nothing
  /// cached is shown by the day's own error state after the re-read.
  Future<void> _refresh(WidgetRef ref) async {
    try {
      await ref.read(swrRepositoryProvider).watchDay(day).drain<void>();
    } on ApiFailure {
      // Shown below: with a cache the day keeps its rows and the age, without one it
      // fails again on the re-read.
    }
    if (!ref.context.mounted) return;
    ref.invalidate(matchesDayProvider(day));
  }
}

class _Pullable extends StatelessWidget {
  const _Pullable({
    required this.onRefresh,
    required this.color,
    required this.background,
    required this.slivers,
  });

  final Future<void> Function() onRefresh;
  final Color color;
  final Color background;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        color: color,
        backgroundColor: background,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      );
}

class _FailedState extends StatelessWidget {
  const _FailedState({required this.failure, required this.onRetry});

  final ApiFailure failure;

  /// Null while a retry is out.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // No connection has its own words; every other failure maps its `error.code`.
    final offline = failure.isOffline;
    return EmptyState(
      kind: EmptyStateKind.error,
      title: offline ? l.noConnectionTitle : l.loadFailedTitle,
      body: offline ? l.noConnectionBody : l.errorCopy(failure.code),
      action: _TextAction(label: l.retry, onPressed: onRetry),
    );
  }
}

/// The one quiet action under an empty or error state: the screen's accent stays on the
/// selected day.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: context.madarColors.textPrimary),
        child: Text(label),
      );
}
