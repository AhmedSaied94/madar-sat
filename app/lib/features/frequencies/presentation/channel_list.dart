import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/generated/models/category.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/carriage_row.dart';
import '../../../design/components/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/channel_filter.dart';
import 'frequencies_state.dart';
import 'open_reception.dart';

/// One tab of S5.2: the channels of [category] that match the search, one `CarriageRow` each.
///
/// The rows build lazily, so a satellite with 130 channels stays cheap. Opening a row shows
/// the S3 details in place, one row at a time.
class ChannelList extends ConsumerWidget {
  const ChannelList({
    super.key,
    required this.satelliteId,
    required this.category,
    required this.channels,
    required this.receptionUrl,
  });

  final int satelliteId;
  final Category category;
  final List<ChannelCarriage> channels;

  /// The reception video, when the satellite has one the app will open.
  final Uri? receptionUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final query = ref.watch(channelSearchProvider(satelliteId));
    final openId = ref.watch(expandedChannelProvider(satelliteId));
    final rows = filterChannels(channels, category: category, query: query);

    if (rows.isEmpty) {
      return query.trim().isNotEmpty
          ? EmptyState(title: l.s5NoResultsTitle, body: l.s5NoResultsBody)
          : EmptyState(
              title: category == Category.sports ? l.s5NoSportsTitle : l.s5NoEntertainmentTitle,
            );
    }

    final reception = receptionUrl;
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (context, index) => Divider(
        height: MadarLine.hairline,
        thickness: MadarLine.hairline,
        color: colors.divider,
      ),
      itemBuilder: (context, index) {
        final channel = rows[index];
        final open = channel.id == openId;
        return CarriageRow(
          key: ValueKey(channel.id),
          carriage: open ? channel : _inSatellite(channel),
          expanded: open,
          onTap: () => ref.read(expandedChannelProvider(satelliteId).notifier).toggle(channel.id),
          onOpenChannel: () => context.push('/channel/${channel.id}'),
          onWatchReception:
              reception == null ? null : () => openReception(context, ref, reception),
        );
      },
    );
  }

  /// Every row here is on the same satellite, so the collapsed row leaves out the satellite
  /// badge the S3 row carries (the design's S5.2 rows show only the readout). A channel with
  /// no frequency keeps its satellite: the row shows its frequency note only beside one. The
  /// opened row keeps everything, so its details are the same as S3's.
  static ChannelCarriage _inSatellite(ChannelCarriage channel) =>
      channel.frequency == null ? channel : channel.copyWith(satellite: null);
}
