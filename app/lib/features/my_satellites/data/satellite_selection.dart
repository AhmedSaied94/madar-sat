import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/generated/models/satellite.dart';
import 'my_satellites_provider.dart';

part 'satellite_selection.g.dart';

/// The chips on S4: my satellites that the server lists, in the server's order.
@riverpod
List<Satellite> mySatelliteChips(Ref ref) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  final mine = ref.watch(mySatelliteIdsProvider);
  if (satellites == null) return const [];
  return [
    for (final satellite in satellites)
      if (mine.contains(satellite.id)) satellite,
  ];
}

/// Which of my satellites S4 shows. `null` is every one of them: the default, and what
/// «الكل» returns to. D3 replaces "my satellites" with the user's saved choice (S1.3, S15);
/// until then the toggles live only for the session.
@Riverpod(keepAlive: true)
class SatelliteSelection extends _$SatelliteSelection {
  @override
  Set<int>? build() => null;

  void toggle(int satelliteId) {
    final mine = ref.read(mySatelliteIdsProvider);
    // The selection as the screen sees it (see [selectedSatelliteIdsProvider]).
    final next = {...(state?.intersection(mine) ?? mine)};
    if (!next.remove(satelliteId)) next.add(satelliteId);
    // All of them again is the default, so a later change to "my satellites" still follows.
    state = next.length == mine.length && next.containsAll(mine) ? null : next;
  }

  void selectAll() => state = null;
}

/// The ids S4 asks the server about: the selection inside my satellites. Empty means nothing
/// is chosen, and S4 then asks for nothing rather than for "no filter".
@riverpod
Set<int> selectedSatelliteIds(Ref ref) {
  final mine = ref.watch(mySatelliteIdsProvider);
  final selection = ref.watch(satelliteSelectionProvider);
  return selection == null ? mine : selection.intersection(mine);
}
