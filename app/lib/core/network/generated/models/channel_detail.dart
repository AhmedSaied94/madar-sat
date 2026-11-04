// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'access.dart';
import 'beam.dart';
import 'category.dart';
import 'channel_carriage.dart';
import 'frequency.dart';
import 'frequency_change.dart';
import 'kind.dart';
import 'match_summary.dart';
import 'satellite_ref.dart';

part 'channel_detail.freezed.dart';
part 'channel_detail.g.dart';

@Freezed()
abstract class ChannelDetail with _$ChannelDetail {
  const factory ChannelDetail({
    required Access? access,
    required Beam? beam,
    required Category? category,
    required String? country,
    @JsonKey(name: 'display_name')
    required String? displayName,
    required Frequency? frequency,
    @JsonKey(name: 'frequency_changed_at')
    required DateTime? frequencyChangedAt,
    @JsonKey(name: 'frequency_note')
    required String? frequencyNote,
    required int id,
    required Kind kind,
    required String? logo,
    required String name,
    @JsonKey(name: 'other_carriages')
    required List<ChannelCarriage> otherCarriages,
    required String? package,
    required String? provider,
    @JsonKey(name: 'recent_frequency_changes')
    required List<FrequencyChange> recentFrequencyChanges,
    required SatelliteRef? satellite,
    @JsonKey(name: 'upcoming_matches')
    required List<MatchSummary> upcomingMatches,
  }) = _ChannelDetail;
  
  factory ChannelDetail.fromJson(Map<String, Object?> json) => _$ChannelDetailFromJson(json);
}
