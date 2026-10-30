import '../../../core/network/generated/models/carriage_entry.dart';
import '../../../core/network/generated/models/channel_carriage.dart';

/// A match's [CarriageEntry] as the [ChannelCarriage] `CarriageRow` draws.
///
/// The two carry the same link fields; an entry also lists the commentators of this match
/// on this channel, which S3 draws under the row, not in it.
ChannelCarriage carriageOf(CarriageEntry entry) => ChannelCarriage(
      id: entry.id,
      kind: entry.kind,
      name: entry.name,
      displayName: entry.displayName,
      logo: entry.logo,
      category: entry.category,
      satellite: entry.satellite,
      frequency: entry.frequency,
      frequencyNote: entry.frequencyNote,
      access: entry.access,
      provider: entry.provider,
      package: entry.package,
      beam: entry.beam,
      country: entry.country,
      frequencyChangedAt: entry.frequencyChangedAt,
    );
