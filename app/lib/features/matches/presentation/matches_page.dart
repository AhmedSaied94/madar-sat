import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/date_strip.dart';
import '../../../design/components/filter_chip_row.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../live/live_merge.dart';
import '../../system/data/connectivity.dart';
import '../../live/live_poller.dart';
import '../data/matches_providers.dart';
import '../domain/matches_day.dart';
import 'day_page.dart';
import 'matches_selection.dart';

/// S2 Matches: the kept local days as pages, with the date strip and chips above them.
///
/// The pages sit in a `PageView` inside the app's RTL `Directionality`, so day 0 is on the
/// right and a swipe toward the right reveals the next day. The strip, the date in words and
/// the page are three views of one selection (`matchesSelectionProvider`); the days
/// themselves come from `matchesWindowProvider`, which a resume past midnight recomputes so
/// no `setState` keeps a stale «اليوم».
class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  late final PageController _pager = PageController(initialPage: MatchesDays.todayIndex);
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// A phone left with the app open past midnight comes back on yesterday's «اليوم»; asking
  /// for the window again is enough, and [build]'s listener moves the selection if it moved.
  void _onLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(matchesWindowProvider);
  }

  /// A tap on the strip or on «اليوم». Neighbours slide; farther days jump, so the days in
  /// between are never built and never requested.
  void _select(List<DateTime> days, DateTime day) {
    final target = days.indexOf(day);
    if (target < 0 || !_pager.hasClients) return;
    ref.read(matchesSelectionProvider.notifier).selectDay(target);
    final current = _pager.page?.round() ?? target;
    final adjacent = (target - current).abs() == 1;
    if (adjacent && !MediaQuery.disableAnimationsOf(context)) {
      _pager.animateToPage(
        target,
        duration: Durations.medium2,
        curve: Curves.easeOutCubic,
      );
    } else {
      _pager.jumpToPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final window = ref.watch(matchesWindowProvider);
    final days = window.days;

    ref.listen(matchesWindowProvider, (previous, next) {
      if (previous == null || previous.today == next.today) return;
      ref.read(matchesSelectionProvider.notifier).selectDay(MatchesDays.todayIndex);
      if (_pager.hasClients) _pager.jumpToPage(MatchesDays.todayIndex);
    });

    final selection = ref.watch(matchesSelectionProvider);
    final selected = days[selection.dayIndex.clamp(0, days.length - 1)];
    final state = ref.watch(matchesDayStateProvider(selected));
    final view = state is DayLoaded ? state.view : null;
    // The cached rows, before the live merge: a day whose copy says "in play" is exactly
    // the day to ask `/v1/live` about (FR-047).
    final cachedRows = view?.snapshot.data;
    final now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LivePollingScope(
          hasLiveOrImminent:
              cachedRows != null && hasLiveOrImminent(cachedRows, now: now),
          onRevalidate: () => ref.read(matchesDayProvider(selected).notifier).revalidate(),
          // Stretch: a horizontal scroller (the chips) otherwise shrinks to its content and
          // centres itself.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MadarTopBar.root(onSearch: () => context.push('/search')),
              // S0 offline-with-cache (R29): the banner carries the newest copy's age and
              // pushes the content down instead of covering it.
              if (!ref.watch(connectivityStatusProvider))
                OfflineBanner(age: view?.snapshot.age(now)),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s4,
                  vertical: MadarSpace.s2,
                ),
                child: DateStrip(
                  days: MatchesDays.stripWindow(days, selection.dayIndex),
                  selected: selected,
                  today: window.today,
                  onSelect: (day) => _select(days, day),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
                child: SizedBox(
                  height: MadarLayout.touchMin,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          MadarDates.full(l, selected),
                          style: MadarText.textStrong.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      if (selection.dayIndex != MatchesDays.todayIndex)
                        TextButton(
                          onPressed: () => _select(days, window.today),
                          style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                          child: Text(l.today),
                        ),
                    ],
                  ),
                ),
              ),
              FilterChipRow<MatchesFilter>(
                items: [
                  FilterChipItem(value: MatchesFilter.all, label: l.filterAll),
                  FilterChipItem(
                    value: MatchesFilter.live,
                    label: l.live,
                    count: view?.liveCount,
                    // The dot means "something is on": with nothing live the chip is quiet
                    // (US3 scenario 1, constitution IV).
                    isLive: (view?.liveCount ?? 0) > 0,
                  ),
                ],
                selected: selection.filter,
                onSelected: ref.read(matchesSelectionProvider.notifier).selectFilter,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: days.length,
                  onPageChanged: ref.read(matchesSelectionProvider.notifier).selectDay,
                  itemBuilder: (context, index) => DayPage(
                    key: ValueKey(days[index]),
                    day: days[index],
                    filter: selection.filter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MadarBottomNav(
        current: MadarTab.matches,
        onSelect: (tab) => switch (tab) {
          MadarTab.matches => context.go('/'),
          MadarTab.mySatellites => context.go('/my-satellites'),
          MadarTab.frequencies => context.go('/satellites'),
          MadarTab.favorites => context.go('/favorites'),
          MadarTab.more => context.go('/more'),
        },
      ),
    );
  }
}
