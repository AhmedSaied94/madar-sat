import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/network/generated/models/satellite.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../my_satellites/data/my_satellites_provider.dart';

List<ChannelCarriage> parseChannels(Object? data) => [
      for (final item in data! as List<Object?>)
        ChannelCarriage.fromJson((item! as Map).cast<String, Object?>()),
    ];

/// `/v1/satellites/{id}/channels`, stale-while-revalidate (24 h freshness).
///
/// The whole list is fetched once, and the screen filters it by category and search
/// locally, so switching tabs or typing never costs a request (S5.2, R25). No automatic
/// retry: the error copy and «إعادة المحاولة» show at once.
final satelliteChannelsProvider = StreamProvider.autoDispose
    .family<SwrSnapshot<List<ChannelCarriage>>, int>(
  (ref, satelliteId) => ref.watch(swrRepositoryProvider).watchDocument<List<ChannelCarriage>>(
        key: DocumentKeys.satelliteChannels(satelliteId),
        path: '/v1/satellites/$satelliteId/channels',
        parse: parseChannels,
      ),
  retry: (retryCount, error) => null,
);

/// The satellite's own entry from the cached list (name, position, aids, reception video),
/// or null while the list has not loaded or when it does not hold this satellite.
final satelliteByIdProvider = Provider.autoDispose.family<Satellite?, int>((ref, satelliteId) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return null;
  for (final satellite in satellites) {
    if (satellite.id == satelliteId) return satellite;
  }
  return null;
});
