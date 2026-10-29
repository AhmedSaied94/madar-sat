// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'access.dart';
import 'frequency.dart';
import 'satellite_ref.dart';

part 'headline_entry.freezed.dart';
part 'headline_entry.g.dart';

@Freezed()
abstract class HeadlineEntry with _$HeadlineEntry {
  const factory HeadlineEntry({
    required Access? access,
    @JsonKey(name: 'channel_id')
    required int channelId,
    required Frequency? frequency,
    required String name,
    required SatelliteRef? satellite,
  }) = _HeadlineEntry;
  
  factory HeadlineEntry.fromJson(Map<String, Object?> json) => _$HeadlineEntryFromJson(json);
}
