import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../my_satellites/data/my_satellites_provider.dart';

part 'satellite_channels_provider.g.dart';

/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.
@Riverpod(retry: _never)
class SatelliteChannels extends _$SatelliteChannels {
  @override
  Stream<SwrSnapshot<List<ChannelCarriage>>> build(int satelliteId) =>
      ref.watch(swrRepositoryProvider).watchSatelliteChannels(satelliteId);

  /// Pull to refresh: the whole cycle, then a re-read.
  Future<void> refresh() async {
    try {
      await ref.read(swrRepositoryProvider).watchSatelliteChannels(satelliteId).drain<void>();
    } on ApiFailure {
      // The state keeps what it has; the screen says so.
    }
    // A disposed provider throws here; the screen that pulled may already be gone (M-R2-2).
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

/// The satellite's own entry from the cached list (name, position, aids, reception video),
/// or null while the list has not loaded or when it does not hold this satellite.
@riverpod
Satellite? satelliteById(Ref ref, int satelliteId) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return null;
  for (final satellite in satellites) {
    if (satellite.id == satelliteId) return satellite;
  }
  return null;
}

Duration? _never(int retryCount, Object error) => null;
