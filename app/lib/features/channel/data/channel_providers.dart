import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/channel_detail.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';

part 'channel_providers.g.dart';

/// `GET /v1/channels/{id}`, stale-while-revalidate from `cached_documents` under
/// `channel:<id>`: the cached copy first, then the revalidated one (§S6, FR-046).
///
/// Invalidate it to revalidate again («تحديث», the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.
@Riverpod(name: 'channelDetailProvider', retry: _never)
class ChannelDetailSource extends _$ChannelDetailSource {
  @override
  Stream<SwrSnapshot<ChannelDetail>> build(int channelId) =>
      ref.watch(swrRepositoryProvider).watchChannelDetail(channelId);

  /// The retry: read again, and keep whatever the cache or the error says meanwhile.
  void revalidate() => ref.invalidateSelf();

  /// A user-initiated refresh: revalidate and wait for the server before reading again.
  Future<void> refresh() async {
    try {
      await ref.read(swrRepositoryProvider).watchChannelDetail(channelId).drain<void>();
    } on ApiFailure {
      // The state keeps the cached copy or its error; the sheet says which.
    }
    // A disposed provider throws here; the sheet that pulled may already be gone.
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

Duration? _never(int retryCount, Object error) => null;
