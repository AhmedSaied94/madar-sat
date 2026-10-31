import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/generated/models/category.dart';

part 'frequencies_state.g.dart';

/// The text typed in S5.1's search field.
@riverpod
class SatelliteSearch extends _$SatelliteSearch {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// S5.2's per-satellite screen state. They are families keyed by the satellite, so one
/// satellite's search or open row never leaks into another's.
@riverpod
class ChannelSearch extends _$ChannelSearch {
  @override
  String build(int satelliteId) => '';

  void set(String query) => state = query;
}

/// The tab S5.2 is on. The page view and the segmented control both write it.
@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  Category build(int satelliteId) => Category.sports;

  void select(Category category) => state = category;
}

/// The channel whose row is open, if any. One at a time (CarriageRow README).
@riverpod
class ExpandedChannel extends _$ExpandedChannel {
  @override
  int? build(int satelliteId) => null;

  void toggle(int channelId) => state = state == channelId ? null : channelId;
}
