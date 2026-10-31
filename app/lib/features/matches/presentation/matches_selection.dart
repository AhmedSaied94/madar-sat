import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/matches_day.dart';

part 'matches_selection.g.dart';

/// What the user has picked on S2: a day among the kept days, and a chip.
class MatchesSelection {
  const MatchesSelection({required this.dayIndex, required this.filter});

  /// An index into the kept days (`matchesWindowProvider`).
  final int dayIndex;
  final MatchesFilter filter;

  MatchesSelection copyWith({int? dayIndex, MatchesFilter? filter}) =>
      MatchesSelection(dayIndex: dayIndex ?? this.dayIndex, filter: filter ?? this.filter);
}

/// Lives as long as the screen does: leaving S2 for a root tab starts again on today.
@Riverpod(name: 'matchesSelectionProvider')
class MatchesSelectionNotifier extends _$MatchesSelectionNotifier {
  @override
  MatchesSelection build() =>
      const MatchesSelection(dayIndex: MatchesDays.todayIndex, filter: MatchesFilter.all);

  void selectDay(int index) {
    if (index != state.dayIndex) state = state.copyWith(dayIndex: index);
  }

  void selectFilter(MatchesFilter filter) {
    if (filter != state.filter) state = state.copyWith(filter: filter);
  }
}
