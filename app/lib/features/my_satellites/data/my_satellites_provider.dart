import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/generated/models/satellite_ref.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';

/// "My satellites" until D3 stores the user's choice (O10, FR-043): Nilesat 7.0W and Badr,
/// found by slug because ids are assigned by the database.
abstract final class MySatellites {
  static const Set<String> defaultSlugs = {'nilesat-7-0w', 'badr-26-0e'};

  /// True when [satellite] is one of my satellites; a carriage without one is not.
  static bool isMine(SatelliteRef? satellite) =>
      satellite != null && defaultSlugs.contains(satellite.slug);
}

List<Satellite> parseSatellites(Object? data) => [
      for (final item in data! as List<Object?>)
        Satellite.fromJson((item! as Map).cast<String, Object?>()),
    ];

/// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
/// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
/// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».
final satellitesProvider = StreamProvider<SwrSnapshot<List<Satellite>>>(
  (ref) => ref.watch(swrRepositoryProvider).watchDocument<List<Satellite>>(
        key: DocumentKeys.satellites,
        path: '/v1/satellites',
        parse: parseSatellites,
      ),
  retry: (retryCount, error) => null,
);

/// The ids of my satellites, resolved from [satellitesProvider]. Empty until the list has
/// loaded (or when the server lists neither), never a guess.
final mySatelliteIdsProvider = Provider<Set<int>>((ref) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return const {};
  return {
    for (final satellite in satellites)
      if (MySatellites.defaultSlugs.contains(satellite.slug)) satellite.id,
  };
});
