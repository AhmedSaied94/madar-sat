import '../../../core/network/generated/models/access.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import '../../../core/network/generated/models/channel_detail.dart';
import '../../../core/network/generated/models/frequency.dart';
import '../../../core/network/generated/models/frequency_change.dart';
import '../../../core/network/generated/models/frequency_change_tuning.dart';

/// S6's own carriage, as the card at the top of the sheet draws it: the satellite, the
/// tuning, the access and the package, read off the channel itself.
class ChannelCarriageView {
  const ChannelCarriageView({
    required this.name,
    required this.header,
    required this.satelliteNameAr,
    required this.satelliteNameEn,
    required this.frequency,
    required this.frequencyNote,
    required this.access,
    required this.provider,
    required this.package,
  });

  /// The sheet builds this from the detail it already has (§S6).
  factory ChannelCarriageView.of(ChannelDetail detail) => ChannelCarriageView(
        name: detail.displayName ?? detail.name,
        header: detail.name,
        satelliteNameAr: detail.satellite?.nameAr,
        satelliteNameEn: detail.satellite?.nameEn,
        frequency: detail.frequency,
        frequencyNote: detail.frequencyNote,
        access: detail.access,
        provider: detail.provider,
        package: detail.package,
      );

  final String name;

  /// The Latin channel name, drawn as an LTR island.
  final String header;
  final String? satelliteNameAr;
  final String? satelliteNameEn;
  final Frequency? frequency;
  final String? frequencyNote;
  final Access? access;
  final String? provider;
  final String? package;
}

/// The channel's other carriages, in the order S6 lists them: on my satellites first, then
/// the free ones, then the rest, each group by satellite and name.
List<ChannelCarriage> otherCarriages(
  ChannelDetail detail, {
  required Set<int> mySatelliteIds,
}) {
  bool mine(ChannelCarriage carriage) =>
      carriage.satellite != null && mySatelliteIds.contains(carriage.satellite!.id);
  bool free(ChannelCarriage carriage) => carriage.access == Access.free;

  final carriages = [...detail.otherCarriages];
  carriages.sort((a, b) {
    // A carriage with no satellite (terrestrial) sorts last: it is not on any satellite the
    // person may already be pointing at.
    final onSatelliteA = a.satellite != null;
    final onSatelliteB = b.satellite != null;
    if (onSatelliteA != onSatelliteB) return onSatelliteA ? -1 : 1;
    if (mine(a) != mine(b)) return mine(a) ? -1 : 1;
    if (free(a) != free(b)) return free(a) ? -1 : 1;
    final bySatellite = (a.satellite?.nameAr ?? '').compareTo(b.satellite?.nameAr ?? '');
    if (bySatellite != 0) return bySatellite;
    final byName = (a.displayName ?? a.name).compareTo(b.displayName ?? b.name);
    if (byName != 0) return byName;
    return a.id.compareTo(b.id);
  });
  return carriages;
}

/// One past tuning of a channel: what it was, what it became, and when.
class FrequencyChangeView {
  const FrequencyChangeView({
    required this.detectedAt,
    required this.before,
    required this.after,
  });

  /// When the change was seen (UTC).
  final DateTime detectedAt;
  final Frequency before;
  final Frequency after;
}

/// How many changes the sheet lists (§S6: the last three).
const int frequencyHistoryLimit = 3;

/// `ChannelDetail.recent_frequency_changes` as the sheet lists it: newest first, at most
/// [frequencyHistoryLimit].
///
/// The API keeps the list empty until D6 records changes (`FrequencyChange`), so this is
/// only ever empty today; the ordering and the cap are here so D6 has nothing to add.
List<FrequencyChangeView> frequencyHistory(
  List<FrequencyChange> raw, {
  int limit = frequencyHistoryLimit,
}) {
  final changes = [
    for (final change in raw)
      FrequencyChangeView(
        detectedAt: change.detectedAt,
        before: _frequency(change.old),
        after: _frequency(change.newValue),
      ),
  ]..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  return changes.take(limit).toList(growable: false);
}

Frequency _frequency(FrequencyChangeTuning tuning) => Frequency(
      mhz: tuning.frequencyMhz,
      pol: tuning.polarization,
      sr: tuning.symbolRate,
    );
