import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
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

/// The ids of my satellites, resolved from [satellitesProvider]. Empty until the list has
/// loaded (or when the server lists neither), never a guess.
@riverpod
Set<int> mySatelliteIds(Ref ref) {
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
  return [
    for (final satellite in satellites)
      if (MySatellites.defaultSlugs.contains(satellite.slug)) satellite,
  ];
}

/// Their Arabic names, for a title that names them: «على نايل سات وبدر».
@riverpod
List<String> mySatelliteNames(Ref ref) =>
    [for (final satellite in ref.watch(mySatelliteEntriesProvider)) satellite.nameAr];

/// The satellites the user chose, or null until D3 stores a choice. While it is null the
/// O10 default set stands in, and S3 titles it by name rather than as «على أقمارك»
/// (constitution I: the screen may not call two bundled defaults "yours").
@Riverpod(keepAlive: true)
Set<int>? chosenSatelliteIds(Ref ref) => null;

Duration? _never(int retryCount, Object error) => null;
