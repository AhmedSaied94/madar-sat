import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/generated/models/category.dart';

/// The text typed in S5.1's search field.
class SatelliteSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final satelliteSearchProvider =
    NotifierProvider.autoDispose<SatelliteSearch, String>(SatelliteSearch.new);

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.
class ChannelSearch extends Notifier<String> {
  ChannelSearch(this.satelliteId);

  final int satelliteId;

  @override
  String build() => '';

  void set(String query) => state = query;
}

final channelSearchProvider =
    NotifierProvider.autoDispose.family<ChannelSearch, String, int>(ChannelSearch.new);

/// The tab S5.2 is on. The page view and the segmented control both write it.
class SelectedCategory extends Notifier<Category> {
  SelectedCategory(this.satelliteId);

  final int satelliteId;

  @override
  Category build() => Category.sports;

  void select(Category category) => state = category;
}

final selectedCategoryProvider = NotifierProvider.autoDispose
    .family<SelectedCategory, Category, int>(SelectedCategory.new);

/// The channel whose row is open, if any. One at a time (CarriageRow README).
class ExpandedChannel extends Notifier<int?> {
  ExpandedChannel(this.satelliteId);

  final int satelliteId;

  @override
  int? build() => null;

  void toggle(int channelId) => state = state == channelId ? null : channelId;
}

final expandedChannelProvider =
    NotifierProvider.autoDispose.family<ExpandedChannel, int?, int>(ExpandedChannel.new);
