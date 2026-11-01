import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../domain/default_satellites.dart';

part 'my_satellites_provider.g.dart';

/// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
/// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
/// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».
@Riverpod(retry: _never)
class Satellites extends _$Satellites {
  @override
  Stream<SwrSnapshot<List<Satellite>>> build() =>
      ref.watch(swrRepositoryProvider).watchSatellites();

  /// The poll: read again through the provider's own stream.
  void revalidate() => ref.invalidateSelf();

  /// Pull to refresh: the whole cache, revalidate and write cycle, then a re-read.
  Future<void> refresh() async {
    try {
      await ref.read(swrRepositoryProvider).watchSatellites().drain<void>();
    } on ApiFailure {
      // The state keeps the cached copy or its error; the screen says which.
    }
    // A disposed provider throws here; the screen that pulled may already be gone (M-R2-2).
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

/// The ids of my satellites: the person's own choice once S1.3 or S15 stored one, otherwise
/// O10's default set resolved through the catalogue. Empty until the list has loaded (or
/// when the server lists neither), never a guess.
@riverpod
Set<int> mySatelliteIds(Ref ref) {
  final chosen = ref.watch(chosenSatelliteIdsProvider);
  if (chosen != null) return chosen;
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return const {};
  return {
    for (final satellite in satellites)
      if (MySatellites.defaultSlugs.contains(satellite.slug)) satellite.id,
  };
}

/// My satellites as the catalogue lists them, in its order.
@riverpod
List<Satellite> mySatelliteEntries(Ref ref) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return const [];
  final chosen = ref.watch(chosenSatelliteIdsProvider);
  return [
    for (final satellite in satellites)
      if (chosen == null
          ? MySatellites.defaultSlugs.contains(satellite.slug)
          : chosen.contains(satellite.id))
        satellite,
  ];
}

/// Their Arabic names, for a title that names them: «على نايل سات وبدر».
@riverpod
List<String> mySatelliteNames(Ref ref) =>
    [for (final satellite in ref.watch(mySatelliteEntriesProvider)) satellite.nameAr];

/// The satellites the person chose in S1.3 or S15, or null while no choice was made. While
/// it is null the O10 default set stands in, and S3 offers «حدد أقمارك» rather than calling
/// two bundled defaults "yours" (constitution I).
@Riverpod(keepAlive: true)
Set<int>? chosenSatelliteIds(Ref ref) {
  final ids = ref.watch(settingsProvider).satelliteIds;
  return ids.isEmpty ? null : ids;
}

/// True when the default set stands in for a choice the person has not made yet: S3 then
/// shows «حدد أقمارك» instead of calling the defaults "yours" (constitution I).
@riverpod
bool usesDefaultSatellites(Ref ref) => ref.watch(chosenSatelliteIdsProvider) == null;

Duration? _never(int retryCount, Object error) => null;
