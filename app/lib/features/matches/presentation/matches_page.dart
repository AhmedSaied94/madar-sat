import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/clock.dart';
import '../../../core/l10n/dates.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/date_strip.dart';
import '../../../design/components/filter_chip_row.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../data/matches_providers.dart';
import '../domain/matches_day.dart';
import 'day_page.dart';
import 'matches_selection.dart';

/// S2 Matches: the kept local days as pages, with the date strip and chips above them.
///
/// The pages sit in a `PageView` inside the app's RTL `Directionality`, so day 0 is on the
/// right and a swipe toward the right reveals the next day. The strip, the date in words and
/// the page are three views of one selection (`matchesSelectionProvider`).
class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});

  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> with WidgetsBindingObserver {
  late final PageController _pager = PageController(initialPage: MatchesDays.todayIndex);
  late DateTime _today = _dayOf(ref.read(clockProvider)());
  late List<DateTime> _days = MatchesDays.kept(_today);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pager.dispose();
    super.dispose();
  }

  static DateTime _dayOf(DateTime instant) => DateTime(instant.year, instant.month, instant.day);

  /// A phone left with the app open past midnight comes back on yesterday's «اليوم» and a
  /// window of days that starts a day late, so on resume a new date opens the new today.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _dayOf(ref.read(clockProvider)());
    if (today == _today) return;
    setState(() {
      _today = today;
      _days = MatchesDays.kept(today);
    });
    ref.read(matchesSelectionProvider.notifier).selectDay(MatchesDays.todayIndex);
    if (_pager.hasClients) _pager.jumpToPage(MatchesDays.todayIndex);
  }

  /// A tap on the strip or on «اليوم». Neighbours slide; farther days jump, so the days in
  /// between are never built and never requested.
  void _select(DateTime day) {
    final target = _days.indexOf(day);
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
    final selection = ref.watch(matchesSelectionProvider);
    final selected = _days[selection.dayIndex];
    final state = ref.watch(matchesDayStateProvider(selected));
    final view = state is DayLoaded ? state.view : null;
    final now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: LivePollingScope(
          hasLiveOrImminent: view != null && hasLiveOrImminent(view.rows, now: now),
          onRevalidate: () => ref.invalidate(matchesDayProvider(selected)),
          // Stretch: a horizontal scroller (the chips) otherwise shrinks to its content and
          // centres itself.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MadarTopBar.root(onSearch: () => context.push('/search')),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s4,
                  vertical: MadarSpace.s2,
                ),
                child: DateStrip(
                  days: MatchesDays.stripWindow(_days, selection.dayIndex),
                  selected: selected,
                  today: _today,
                  onSelect: _select,
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
                          onPressed: () => _select(_today),
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
                    isLive: true,
                  ),
                ],
                selected: selection.filter,
                onSelected: ref.read(matchesSelectionProvider.notifier).selectFilter,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pager,
                  itemCount: _days.length,
                  onPageChanged: ref.read(matchesSelectionProvider.notifier).selectDay,
                  itemBuilder: (context, index) => DayPage(
                    key: ValueKey(_days[index]),
                    day: _days[index],
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
          MadarTab.more => context.go('/settings'),
        },
      ),
    );
  }
}
