import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/matches_day.dart';

/// What the user has picked on S2: a day among the kept days, and a chip.
class MatchesSelection {
  const MatchesSelection({required this.dayIndex, required this.filter});

  /// An index into `MatchesDays.kept`.
  final int dayIndex;
  final MatchesFilter filter;

  MatchesSelection copyWith({int? dayIndex, MatchesFilter? filter}) =>
      MatchesSelection(dayIndex: dayIndex ?? this.dayIndex, filter: filter ?? this.filter);
}

class MatchesSelectionNotifier extends Notifier<MatchesSelection> {
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

/// Lives as long as the screen does: leaving S2 for a root tab starts again on today.
final matchesSelectionProvider =
    NotifierProvider.autoDispose<MatchesSelectionNotifier, MatchesSelection>(
  MatchesSelectionNotifier.new,
);
