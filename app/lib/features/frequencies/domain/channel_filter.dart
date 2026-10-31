import '../../../core/network/generated/models/category.dart';
import '../../../core/network/generated/models/channel_carriage.dart';
import 'search_normalize.dart';

/// The tab a channel is listed under on S5.2: sports, or entertainment. A channel the admin
/// has not categorised is listed with entertainment rather than lost, so every channel the
/// header counts is on one of the two tabs.
Category categoryOf(ChannelCarriage channel) =>
    channel.category == Category.sports ? Category.sports : Category.entertainment;

/// How many channels each tab holds, from the whole list (the search does not change them).
({int sports, int entertainment}) channelCounts(List<ChannelCarriage> channels) {
  final sports = channels.where((channel) => categoryOf(channel) == Category.sports).length;
  return (sports: sports, entertainment: channels.length - sports);
}

final RegExp _digitsOnly = RegExp(r'^\d+$');

/// The channels of [category] that match [query], in the server's order.
///
/// The same rule as `/v1/satellites/{id}/channels?q=`, run locally so the list is fetched
/// once: the text matches a channel's name or display name, and a query of digits alone also
/// matches the start of its frequency in MHz (`11843`, or `118` on the way there).
List<ChannelCarriage> filterChannels(
  List<ChannelCarriage> channels, {
  required Category category,
  String query = '',
}) {
  final needle = normalizeSearch(query);
  final byDigits = _digitsOnly.hasMatch(needle);
  bool matches(ChannelCarriage channel) {
    if (needle.isEmpty) return true;
    if (normalizeSearch(channel.name).contains(needle)) return true;
    if (normalizeSearch(channel.displayName).contains(needle)) return true;
    final frequency = channel.frequency;
    return byDigits && frequency != null && '${frequency.mhz}'.startsWith(needle);
  }

  return [
    for (final channel in channels)
      if (categoryOf(channel) == category && matches(channel)) channel,
  ];
}
